//
//  SharedEventSectionView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/28.
//
import SwiftUI
import Foundation
// import FirebaseFirestore  // 如果需要 EventManager 的功能，可能需要这个导入

/// 事件类型分类
enum EventCategory {
    case myOwn        // 自己创建
    case friendShared // 朋友分享
    case groupShared  // 社群分享
    case nearby       // 附近活动
}

struct SharedEventSectionView: View {
    let date: Date
    let events: [Event]
    let currentUserOpenid: String
    var allowNavigation: Bool = true
    var onEventUpdated: (() -> Void)? = nil
    var friendIds: Set<String> = []  // 用于判断是否为朋友分享
    var groupIds: Set<String> = []   // 用于判断是否为社群分享
    
    // 多选模式状态（从父视图传入）
    @Binding var isMultiSelectMode: Bool
    @Binding var selectedEventIds: Set<Int>
    
    // 参与状态缓存（eventId -> status）
    @State private var participationStatuses: [Int: String] = [:]
    // 正在加载的状态（避免重复加载）
    @State private var loadingEventIds: Set<Int> = []
    
    // 长按相关状态
    @State private var isLongPressing: Bool = false
    @State private var longPressEventId: Int? = nil
    
    // 编辑事件状态
    @State private var eventToEdit: Event? = nil
    @State private var showEditEvent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let isToday = Calendar.current.isDateInToday(date)

            HStack {
                Text(dateFormatter.string(from: date))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(isToday ? .accentColor : .primary)
                if isToday {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal)
            .id(date)

            // 如果没有事件，不显示任何内容
            if events.isEmpty {
                // 空状态 - 不显示任何内容
            }
            
            // 显示所有事件（排除已删除的事件）
            let sortedEvents = events
                .filter { $0.deleted != 1 }  // 排除已删除的事件
                .sorted {
                    ($0.startDateTime ?? .distantPast) < ($1.startDateTime ?? .distantPast)
                }
            ForEach(sortedEvents, id: \.id) { event in
                eventRowWithInteractions(
                    event: event,
                    isMine: event.creatorOpenid == currentUserOpenid
                )
            }

            Divider().padding(.horizontal)
        }
        .sheet(isPresented: $showEditEvent) {
            if let event = eventToEdit {
                NavigationView {
                    EventEditView(
                        viewModel: EventDetailViewModel(event: event),
                        onComplete: {
                            showEditEvent = false
                            eventToEdit = nil
                            onEventUpdated?()
                        }
                    )
                    .environmentObject(FirebaseUserManager.shared)
                }
            }
        }
    }

    @ViewBuilder
    private func eventRowWithInteractions(event: Event, isMine: Bool) -> some View {
        let eventId = event.id ?? 0
        let isSelected = selectedEventIds.contains(eventId)
        let destination = AnyView(EventShareView(event: event, onEventUpdated: onEventUpdated))
        
        HStack(spacing: 12) {
            // 多选模式：显示勾选圈
            if isMultiSelectMode {
                Button(action: {
                    if isSelected {
                        selectedEventIds.remove(eventId)
                    } else {
                        selectedEventIds.insert(eventId)
                    }
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if let start = event.startDateTime {
                Text(timeFormatter.string(from: start))
                .foregroundColor(.gray)
                .font(.subheadline)
                .frame(width: 60, alignment: .trailing)
            }
            
            // 事件内容
            Group {
                if allowNavigation && !isMultiSelectMode {
                    NavigationLink(destination: destination) {
                        eventContent(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    eventContent(event: event)
                        .onTapGesture {
                            if isMultiSelectMode {
                                // 多选模式下点击切换选择状态
                                if isSelected {
                                    selectedEventIds.remove(eventId)
                                } else {
                                    selectedEventIds.insert(eventId)
                                }
                            }
                        }
                }
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
        //修改内容：只保留长按进入多选功能
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.8)
                .onChanged { pressing in
                    // 长按开始时的视觉反馈
                    if pressing && longPressEventId == nil && !isMultiSelectMode {
                        longPressEventId = eventId
                        isLongPressing = true
                        // 触觉反馈
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                }
                .onEnded { _ in
                    // 长按结束，进入多选模式
                    isLongPressing = false
                    longPressEventId = nil
                    
                    if !isMultiSelectMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isMultiSelectMode = true
                            selectedEventIds.insert(eventId)
                        }
                    }
                }
        )

        .task(id: event.id) {
            // 异步加载参与状态
            if let eventId = event.id,
               event.creatorOpenid != currentUserOpenid,
               participationStatuses[eventId] == nil,
               !loadingEventIds.contains(eventId) {
                await loadParticipationStatus(eventId: eventId)
            }
        }
    }
    
    @ViewBuilder
    private func eventContent(event: Event) -> some View {
        let eventId = event.id ?? 0
        let isBeingLongPressed = longPressEventId == eventId && isLongPressing
        // 确保当 events 数组变化时重新计算重叠状态
        let hasOverlap = hasTimeOverlap(event: event, targetDate: event.dateObj ?? date)
        
        HStack(spacing: 8) {
            // 时间重叠红点
            if hasOverlap {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
            
            Text(event.title)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(determineColorWithOpacity(for: event))
        .cornerRadius(8)
        .opacity(isBeingLongPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isBeingLongPressed)
        .animation(.easeInOut(duration: 0.2), value: participationStatuses[eventId])
        // 添加对事件关键属性的监听，确保事件更新后重新计算重叠和颜色
        .animation(.easeInOut(duration: 0.2), value: event.startDateTime)
        .animation(.easeInOut(duration: 0.2), value: event.endDateTime)
        .animation(.easeInOut(duration: 0.2), value: event.deleted)
        .animation(.easeInOut(duration: 0.2), value: event.date)
        // 添加对 events 数组的监听，确保其他事件更新后重新计算重叠
        .animation(.easeInOut(duration: 0.2), value: events.map { "\($0.id ?? 0)-\($0.startDateTime?.timeIntervalSince1970 ?? 0)-\($0.endDateTime?.timeIntervalSince1970 ?? 0)" })
    }

    //修改内容：拖动浮层，纯视觉，不带任何手势/导航/异步任务，避免拖动时死机
@ViewBuilder
private func draggingOverlay(event: Event) -> some View {
    let hasOverlap = hasTimeOverlap(event: event, targetDate: event.dateObj ?? date)
    
    HStack(spacing: 12) {
        if let start = event.startDateTime {
            Text(timeFormatter.string(from: start))
                .foregroundColor(.gray)
                .font(.subheadline)
                .frame(width: 60, alignment: .trailing)
        } else {
            Text("")
                .frame(width: 60)
        }
        
        HStack(spacing: 8) {
            if hasOverlap {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
            Text(event.title)
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(determineColorWithOpacity(for: event))
        .cornerRadius(8)
    }
    .padding(.horizontal)
    .background(Color(.systemBackground))
}

    
    /// 加载参与状态
    private func loadParticipationStatus(eventId: Int) async {
        // 避免重复加载
        await MainActor.run {
            if loadingEventIds.contains(eventId) || participationStatuses[eventId] != nil {
                return
            }
            loadingEventIds.insert(eventId)
        }
        
        do {
            let status = try await EventManager.shared.getParticipationStatus(
                eventId: eventId,
                userId: currentUserOpenid
            )
            await MainActor.run {
                // 使用 "shared" 作为默认值，避免 nil 导致的闪烁
                participationStatuses[eventId] = status ?? "shared"
                loadingEventIds.remove(eventId)
            }
        } catch {
            print("加载参与状态失败: \(error.localizedDescription)")
            await MainActor.run {
                // 即使加载失败，也设置一个默认值，避免重复加载
                participationStatuses[eventId] = "shared"
                loadingEventIds.remove(eventId)
            }
        }
    }

    /// 判断事件访问来源（用于颜色判断）
    private func determineAccessSource(for event: Event) -> EventAccessSource {
        // 使用 EventAccessManager 的方法
        return EventAccessManager.shared.determineAccessSourceForColor(
            event: event,
            currentUserId: currentUserOpenid,
            isGroupMember: { groupId in
                guard let groupId = groupId else { return false }
                return groupIds.contains(groupId)
            }
        )
    }
    
    /// 确定颜色和透明度（按照 EVENT_SHARE_VISIBILITY_RULES.md 标准）
    /// 注意：避免在每次调用时创建新的 Date()，使用缓存的当前时间
    private func determineColorWithOpacity(for event: Event) -> Color {
        // 使用缓存的当前时间，避免每次调用都创建新对象（虽然影响很小，但可能导致不必要的重新计算）
        // 在实际应用中，可以考虑在视图级别缓存一个时间戳，每分钟更新一次
        let now = Date()
        
        // 判断事件是否已结束（按照规则：已结束 = 灰色）
        let isEnded: Bool
        if let isAllDay = event.isAllDay, isAllDay {
            // 整日活动：使用日期判断
            let calendar = Calendar.current
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            // 确定结束日期（如果有结束日期则使用，否则使用开始日期）
            let endDateString = event.endDate ?? event.date
            if let endDateObj = dateFormatter.date(from: endDateString) {
                let endOfDay = calendar.startOfDay(for: endDateObj)
                let today = calendar.startOfDay(for: now)
                // 只有当今天已经过了结束日期（不包括今天）才算结束
                isEnded = today > endOfDay
            } else {
                // 如果日期解析失败，视为未结束
                isEnded = false
            }
        } else {
            // 非整日活动：使用结束时间判断
            if let end = event.endDateTime {
                // 有明确的结束时间，直接比较
                isEnded = now > end
            } else if let start = event.startDateTime {
                // 如果没有结束时间，但有开始时间
                // 如果开始时间已过且超过24小时，视为结束
                let hoursSinceStart = now.timeIntervalSince(start) / 3600
                isEnded = hoursSinceStart > 24
            } else {
                // 既没有开始时间也没有结束时间，视为未结束
                isEnded = false
            }
        }
        
        // 已结束：灰色（覆盖所有颜色）- 按照规则文档
        if isEnded {
            return .gray
        }
        
        // 根据访问来源确定基础颜色（按照规则文档）
        let baseColor: Color
        switch determineAccessSource(for: event) {
        case .myOwn, .direct:
            baseColor = .red      // 1. 自己创建的事件：红色
        case .group, .groupMember:
            baseColor = .blue     // 2. 社群活动（group 可见）：蓝色
        case .friendOrShared, .friendShared, .strangerShared:
            baseColor = .green    // 3. 好友可见 / 非好友单一分享 / 邀请链接 / 个人单一分享：绿色
        case .adminOverride:
            baseColor = .purple   // 管理员查看 - 紫色（可选）
        }
        
        // 根据参与状态调整透明度（按照规则文档）
        // 优化：先确定是否是自己的行程，避免在多个地方判断
        let isMyOwn = event.creatorOpenid == currentUserOpenid
        let eventId = event.id
        
        // 确定透明度：优先使用已加载的状态，否则使用默认值
        let opacity: Double
        if let eventId = eventId,
           let status = participationStatuses[eventId] {
            // 已加载的状态
            switch status {
            case "joined":
                opacity = 1.0    // 参与：正常不透明
            case "declined":
                opacity = 0.25   // 不参与：更淡
            default: // "shared" 或其他状态
                opacity = 0.5     // 未表态：半透明
            }
        } else {
            // 无记录时的默认透明度（避免在加载状态时闪烁）
            // 对于自己的行程，始终使用 1.0，不会因为状态加载而改变
            // 对于他人创建的行程，使用 0.5，加载完成后会根据实际状态更新
            opacity = isMyOwn ? 1.0 : 0.5
        }
        
        // 使用固定的透明度值，避免在状态更新时闪烁
        // SwiftUI 的 animation 修饰符会平滑过渡
        return baseColor.opacity(opacity)
    }
    
    // MARK: - 交互功能
    
    /// 软删除事件
    private func softDeleteEvent(eventId: Int) async {
        do {
            try await EventManager.shared.softDeleteEvent(eventId: eventId)
            await MainActor.run {
                onEventUpdated?()
            }
        } catch {
            print("软删除事件失败: \(error.localizedDescription)")
        }
    }
    
    /// 检测事件是否有时间重叠
    private func hasTimeOverlap(event: Event, targetDate: Date) -> Bool {
        // 获取目标日期的所有事件（排除当前事件和已删除的事件）
        let sameDayEvents = events.filter { otherEvent in
            guard let otherEventId = otherEvent.id,
                  let eventId = event.id,
                  otherEventId != eventId,
                  let otherDate = otherEvent.dateObj,
                  // 排除已删除的事件
                  otherEvent.deleted != 1 else {
                return false
            }
            return Calendar.current.isDate(otherDate, inSameDayAs: targetDate)
        }
        
        // 检查是否有时间重叠
        guard let eventStart = event.startDateTime,
              let eventEnd = event.endDateTime else {
            return false
        }
        
        for otherEvent in sameDayEvents {
            guard let otherStart = otherEvent.startDateTime,
                  let otherEnd = otherEvent.endDateTime else {
                continue
            }
            
            // 检查时间是否重叠（使用标准的时间区间重叠判断）
            // 两个时间区间重叠的条件：start1 < end2 && end1 > start2
            if (eventStart < otherEnd && eventEnd > otherStart) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Formatter 共用

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M.d（E）"
    return f
}()

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()

