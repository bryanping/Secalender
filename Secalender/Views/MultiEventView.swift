//
//  MultiEventView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 多行程检视来源
enum MultiEventViewSource {
    case calendar      // 从行事历打开
    case template      // 从行程模版打开（AIPlannerView 或 MyTemplatesView）
}

struct MultiEventView: View {
    let eventIds: [Int]
    @Binding var allEvents: [Event]  // 改为 Binding，可以实时更新
    var source: MultiEventViewSource = .calendar  // 来源标识
    var onComplete: (() -> Void)? = nil
    var onRefreshEvents: (() async -> Void)? = nil  // 刷新事件列表的回调
    var onDismiss: (() -> Void)? = nil  // 关闭页面时的回调（用于刷新和重置状态）
    var onBackToTemplate: (() -> Void)? = nil  // 返回到行程模版的回调（仅当 source == .template 时使用）
    
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    // 本地状态：已删除的事件ID（软删除后从列表中移除）
    @State private var deletedEventIds: Set<Int> = []
    // 全部删除确认对话框
    @State private var showDeleteAllConfirmation = false
    
    // 拖拽排序相关状态
    @State private var draggedEvent: Event? = nil
    @State private var eventsByDate: [(Date, [Event])] = []  // 按日期分组的事件
    @State private var selectedDayIndex: Int = 0  // 当前选中的日期索引
    @State private var eventToEdit: Event? = nil  // 要编辑的事件
    @State private var showEventEditView = false  // 是否显示编辑页面
    @State private var blockToEdit: TimeBlock? = nil  // 要编辑的 Block（智能行程）
    @State private var showBlockEditView = false  // 是否显示 Block 编辑页面
    @State private var planForBlockEdit: PlanResult? = nil  // 用于 BlockEditView 的完整行程
    @State private var eventIdForBlockEdit: Int? = nil  // 要编辑的事件ID（用于保存时匹配）
    
    // 分享和储存相关状态
    @State private var showShareSheet = false  // 显示分享页面
    @State private var showSaveTemplateSheet = false  // 显示储存模板页面
    @State private var showBatchDeleteConfirmation = false  // 批量删除确认对话框
    @State private var selectedEventIds: Set<Int> = []  // 选中的事件ID（用于批量操作）
    @State private var isMultiSelectMode: Bool = false  // 多选模式
    @State private var showPlanEditView = false  // 显示编辑页面
    @State private var planToEdit: PlanResult? = nil  // 要编辑的行程
    @State private var originalEventIdsForEdit: [Int] = []  // 编辑前的原始事件ID列表
    
    // 获取要查看的事件（排除已删除的）
    private var eventsToView: [Event] {
        allEvents.filter { event in
            guard let eventId = event.id else { return false }
            // 排除已删除的事件
            if deletedEventIds.contains(eventId) {
                return false
            }
            return eventIds.contains(eventId)
        }
        .sorted { event1, event2 in
            // 按日期和时间排序
            let date1 = event1.startDateTime ?? .distantPast
            let date2 = event2.startDateTime ?? .distantPast
            return date1 < date2
        }
    }
    
    // 按日期分组事件
    private func groupEventsByDate() -> [(Date, [Event])] {
        let calendar = Calendar.current
        var grouped: [Date: [Event]] = [:]
        
        for event in eventsToView {
            guard let dateObj = event.dateObj else { continue }
            let dayStart = calendar.startOfDay(for: dateObj)
            
            if grouped[dayStart] == nil {
                grouped[dayStart] = []
            }
            grouped[dayStart]?.append(event)
        }
        
        // 按日期排序，并在每个日期内按时间排序
        return grouped.map { (date, events) in
            let sortedEvents = events.sorted { event1, event2 in
                let time1 = event1.startDateTime ?? .distantPast
                let time2 = event2.startDateTime ?? .distantPast
                return time1 < time2
            }
            return (date, sortedEvents)
        }
        .sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 行程内容（按日期分组显示）
                        if eventsToView.isEmpty {
                            emptyStateView
                        } else {
                            eventsListView
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("多行程檢視")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // 根据来源决定返回行为
                        if source == .template {
                            // 从行程模版打开，返回到模版
                            onBackToTemplate?()
                        } else {
                            // 从行事历打开，使用默认返回
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !eventsToView.isEmpty {
                        Menu {
                            Button(action: {
                                showShareSheet = true
                            }) {
                                Label("分享", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: {
                                showSaveTemplateSheet = true
                            }) {
                                Label("轉存模版", systemImage: "bookmark")
                            }
                            
                            // 如果有选中的行程，显示编辑按钮
                            if !selectedEventIds.isEmpty {
                                Divider()
                                
                                Button(action: {
                                    openPlanEditView()
                                }) {
                                    Label("編輯", systemImage: "pencil")
                                }
                            }
                            
                            Divider()
                            
                            Button(role: .destructive, action: {
                                showBatchDeleteConfirmation = true
                            }) {
                                Label("批量刪除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                
                // 多选模式工具栏
                if isMultiSelectMode {
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 16) {
                            Button("取消") {
                                withAnimation {
                                    isMultiSelectMode = false
                                    selectedEventIds.removeAll()
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Text("已選中 \(selectedEventIds.count) 個行程")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button {
                                if !selectedEventIds.isEmpty {
                                    openPlanEditView()
                                }
                            } label: {
                                Label("編輯", systemImage: "pencil")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedEventIds.isEmpty)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                }
            }
        }
        .alert("確認刪除", isPresented: $showBatchDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                deleteSelectedEvents()
            }
        } message: {
            Text("確定要刪除選中的 \(selectedEventIds.count) 個行程嗎？")
        }
        .sheet(isPresented: $showEventEditView) {
            if let event = eventToEdit {
                NavigationView {
                    EventEditView(
                        viewModel: EventDetailViewModel(event: event),
                        onComplete: {
                            Task {
                                await refreshEvents()
                            }
                            showEventEditView = false
                            eventToEdit = nil
                        },
                        onDelete: {
                            if let eventId = event.id {
                                withAnimation {
                                    deletedEventIds.insert(eventId)
                                }
                            }
                            Task {
                                await refreshEvents()
                            }
                            showEventEditView = false
                            eventToEdit = nil
                        },
                        source: .multiView
                    )
                    .environmentObject(userManager)
                }
            }
        }
        .sheet(isPresented: $showBlockEditView) {
            if let block = blockToEdit, let plan = planForBlockEdit {
                BlockEditView(
                    block: block,
                    onSave: { updatedBlock in
                        // 更新 Block 并同步到 Event
                        updateBlockInPlan(updatedBlock)
                        showBlockEditView = false
                        blockToEdit = nil
                        planForBlockEdit = nil
                        eventIdForBlockEdit = nil
                    },
                    onCancel: {
                        showBlockEditView = false
                        blockToEdit = nil
                        planForBlockEdit = nil
                        eventIdForBlockEdit = nil
                    },
                    plan: plan,
                    interestTags: []
                )
                .environmentObject(userManager)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            BatchShareEventsView(
                eventIds: selectedEventIds.isEmpty ? eventIds : Array(selectedEventIds),
                allEvents: allEvents,
                onComplete: {
                    showShareSheet = false
                }
            )
            .environmentObject(userManager)
        }
        .sheet(isPresented: $showSaveTemplateSheet) {
            // 保存为模板的视图（需要创建或使用现有的保存模板视图）
            saveTemplateView
        }
        .sheet(isPresented: $showPlanEditView) {
            if let plan = planToEdit {
                PlanEditView(
                    plan: plan,
                    customTitle: generateTripTitle(),
                    originalEventIds: originalEventIdsForEdit.isEmpty ? nil : originalEventIdsForEdit,
                    onSaveToCalendar: { eventIds in
                        // 保存后刷新数据并返回
                        Task {
                            // 重新加载事件列表
                            await onRefreshEvents?()
                            await refreshEvents()
                            
                            // 更新 eventIds 为保存后的事件ID列表
                            // 注意：这里需要更新父视图的 eventIds，但由于是 let，我们需要通过回调通知
                            await MainActor.run {
                                showPlanEditView = false
                                planToEdit = nil
                                originalEventIdsForEdit = []
                                isMultiSelectMode = false
                                selectedEventIds.removeAll()
                                
                                // 通知父视图刷新
                                onComplete?()
                            }
                        }
                    },
                    onSaveToTemplate: { editedPlan, title in
                        // 转存为模板
                        let templateTitle = title ?? generateTripTitle()
                        saveAsTemplateWithParams(plan: editedPlan, title: templateTitle)
                        showPlanEditView = false
                        planToEdit = nil
                        originalEventIdsForEdit = []
                        isMultiSelectMode = false
                        selectedEventIds.removeAll()
                    },
                    onDismiss: {
                        showPlanEditView = false
                        planToEdit = nil
                        originalEventIdsForEdit = []
                    }
                )
                .environmentObject(userManager)
            }
        }
        .onDisappear {
            // 当页面关闭时，通知父视图刷新并重置状态
            // 注意：如果是从模版打开，onBackToTemplate 会在返回按钮中调用，这里不调用 onDismiss
            if source == .calendar {
                // 刷新数据
                Task {
                    await refreshEvents()
                    await onRefreshEvents?()
                }
                onDismiss?()
            }
        }
        .refreshable {
            // 下拉刷新
            await refreshEvents()
            await onRefreshEvents?()
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("multi_event.all_deleted".localized())
                .font(.headline)
            Text("multi_event.deleted_not_shown".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - 行程列表视图（参考 PlanEditView 的样式）
    private var eventsListView: some View {
        VStack(spacing: 20) {
            ForEach(0..<eventsByDate.count, id: \.self) { dayIndex in
                let dayData = eventsByDate[dayIndex]
                
                // 每个事件作为独立的卡片（类似 PlanEditView 中的 MultiDayEventItemView）
                ForEach(dayData.1, id: \.id) { event in
                    eventCardView(event: event, dayIndex: dayIndex, dayDate: dayData.0)
                }
            }
        }
        .padding(.horizontal)
        .onAppear {
            // 初始化时更新分组数据
            eventsByDate = groupEventsByDate()
        }
        .onChange(of: eventsToView.count) { _, _ in
            // 当事件列表变化时，重新分组
            eventsByDate = groupEventsByDate()
        }
        .onChange(of: allEvents.count) { _, _ in
            // 当所有事件列表变化时，重新分组
            eventsByDate = groupEventsByDate()
        }
    }
    
    // MARK: - 事件卡片视图（参考 PlanEditView 的 MultiDayEventItemView 样式）
    private func eventCardView(event: Event, dayIndex: Int, dayDate: Date) -> some View {
        let eventId = event.id ?? 0
        let isSelected = selectedEventIds.contains(eventId)
        let isAiEvent = event.isAiEvent
        
        // 生成卡片标题（包含日期和智能行程标识）
        let cardTitle: String
        if isAiEvent {
            cardTitle = "行程 \(dayIndex + 1) - \(dayDateFormatter.string(from: dayDate)) ✨"
        } else {
            cardTitle = "行程 \(dayIndex + 1) - \(dayDateFormatter.string(from: dayDate))"
        }
        
        // 外部匯入行程使用灰藍色
        let iconColor: Color = event.isFromExternalImport
            ? Color(red: 0.5, green: 0.65, blue: 0.8)
            : (isAiEvent ? .purple : .blue)
        let iconName = event.isFromExternalImport
            ? "calendar.badge.clock"
            : (isAiEvent ? "sparkles" : "mappin.circle.fill")
        
        return EventFormCard(icon: iconName, title: cardTitle, iconColor: iconColor) {
            VStack(spacing: 16) {
                // 选择框和标题行
                HStack(spacing: 12) {
                    // 选择框（用于批量操作）
                    Button(action: {
                        if isSelected {
                            selectedEventIds.remove(eventId)
                        } else {
                            selectedEventIds.insert(eventId)
                        }
                    }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .secondary)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .opacity(isMultiSelectMode ? 1.0 : 0.0)  // 多选模式才显示
                    
                    // 事件标题
                    Text(event.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 编辑按钮（非多选模式才显示）
                    if !isMultiSelectMode {
                        Button(action: {
                            // 根据类型跳转到不同的编辑页面
                            if isAiEvent {
                                // 智能行程：跳转到 BlockEditView
                                openBlockEditView(for: event)
                            } else {
                                // 普通行程：跳转到 EventEditView
                                eventToEdit = event
                                showEventEditView = true
                            }
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 24))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())  // 扩大点击区域
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
                .onLongPressGesture(minimumDuration: 0.8) {
                    // 长按进入多选模式
                    if !isMultiSelectMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isMultiSelectMode = true
                            selectedEventIds.insert(eventId)
                        }
                    }
                }
                
                // 時間資訊：整日活動顯示「全天」，不顯示 00:00-23:59
                if event.isAllDay == true {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        Text("event_ui.all_day".localized())
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if let start = event.startDateTime {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        Text(timeFormatter.string(from: start))
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        
                        if let end = event.endDateTime, end != start {
                            Text(" - ")
                                .foregroundColor(.secondary)
                            Text(timeFormatter.string(from: end))
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 地点信息
                if !event.destination.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        Text(event.destination)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 备注信息
                if let information = event.information, !information.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        Text(information)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    // MARK: - 移动事件
    private func moveEvent(fromIndex: Int, toIndex: Int, fromDayIndex: Int, toDayIndex: Int) {
        guard fromDayIndex < eventsByDate.count && toDayIndex < eventsByDate.count else { return }
        guard fromIndex < eventsByDate[fromDayIndex].1.count && toIndex <= eventsByDate[toDayIndex].1.count else { return }
        
        var updatedEventsByDate = eventsByDate
        var movedEvent = updatedEventsByDate[fromDayIndex].1[fromIndex]
        
        // 从原位置移除
        updatedEventsByDate[fromDayIndex].1.remove(at: fromIndex)
        
        // 如果移动到不同日期，需要更新事件的日期和时间
        if fromDayIndex != toDayIndex {
            let targetDate = updatedEventsByDate[toDayIndex].0
            let calendar = Calendar.current
            
            // 更新事件的日期
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            movedEvent.date = dateFormatter.string(from: targetDate)
            
            // 保持原有的时间，但更新日期部分
            if let originalStartTime = movedEvent.startDateTime {
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalStartTime)
                if let newStartTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, 
                                                     minute: timeComponents.minute ?? 0, 
                                                     second: timeComponents.second ?? 0, 
                                                     of: targetDate) {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm:ss"
                    movedEvent.startTime = timeFormatter.string(from: newStartTime)
                }
            }
            
            // 更新结束时间（如果有）
            if let originalEndTime = movedEvent.endDateTime {
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalEndTime)
                if let newEndTime = calendar.date(bySettingHour: timeComponents.hour ?? 0, 
                                                  minute: timeComponents.minute ?? 0, 
                                                  second: timeComponents.second ?? 0, 
                                                  of: targetDate) {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm:ss"
                    movedEvent.endTime = timeFormatter.string(from: newEndTime)
                }
            }
            
            // 保存更新后的事件到 Firebase（异步）
            Task {
                do {
                    try await EventManager.shared.updateEvent(event: movedEvent)
                    // 更新本地缓存
                    EventCacheManager.shared.updateEventInCache(movedEvent, for: userManager.userOpenId)
                } catch {
                    print("⚠️ 更新事件日期失败: \(error.localizedDescription)")
                }
            }
        } else {
            // 同一天内移动，需要更新事件的顺序（通过更新时间）
            let calendar = Calendar.current
            let baseDate = updatedEventsByDate[toDayIndex].0
            var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: baseDate) ?? baseDate
            
            // 重新计算所有事件的时间，确保顺序正确
            for (index, var event) in updatedEventsByDate[toDayIndex].1.enumerated() {
                if index == toIndex {
                    // 更新被移动的事件时间
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm:ss"
                    event.startTime = timeFormatter.string(from: currentTime)
                    
                    // 如果有结束时间，设置为开始时间后1小时
                    if let endTime = calendar.date(byAdding: .hour, value: 1, to: currentTime) {
                        event.endTime = timeFormatter.string(from: endTime)
                    }
                    
                    // 保存更新
                    Task {
                        do {
                            try await EventManager.shared.updateEvent(event: event)
                            EventCacheManager.shared.updateEventInCache(event, for: userManager.userOpenId)
                        } catch {
                            print("⚠️ 更新事件时间失败: \(error.localizedDescription)")
                        }
                    }
                    
                    updatedEventsByDate[toDayIndex].1[index] = event
                }
                
                // 为下一个事件增加时间间隔（15分钟）
                currentTime = calendar.date(byAdding: .minute, value: 15, to: currentTime) ?? currentTime
            }
        }
        
        // 插入到新位置
        updatedEventsByDate[toDayIndex].1.insert(movedEvent, at: toIndex)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            eventsByDate = updatedEventsByDate
        }
    }
    
    /// 刷新事件列表
    private func refreshEvents() async {
        // 调用外部刷新回调，重新加载事件
        await onRefreshEvents?()
        // 由于 allEvents 是 Binding，CalendarView 更新后会自动反映到这里
    }
    
    /// 删除选中的行程（批量删除）
    private func deleteSelectedEvents() {
        let eventsToDelete = eventsToView.filter { event in
            guard let eventId = event.id else { return false }
            return selectedEventIds.contains(eventId)
        }
        
        // 立即更新本地缓存和 UI（不等待网络）
        for event in eventsToDelete {
            guard let eventId = event.id else { continue }
            // 立即更新本地缓存
            EventManager.shared.softDeleteEvent(eventId: eventId)
            // 立即更新 UI（从列表中移除）
            deletedEventIds.insert(eventId)
            selectedEventIds.remove(eventId)
        }
        
        // 通知父视图刷新
        Task {
            await refreshEvents()
        }
    }
    
    /// 生成行程标题
    private func generateTripTitle() -> String {
        if eventsToView.isEmpty {
            return "行程"
        }
        
        // 尝试从第一个事件提取目的地
        let firstEvent = eventsToView.first!
        if !firstEvent.destination.isEmpty {
            let destination = firstEvent.destination
            let days = eventsByDate.count
            return "\(destination) \(days)天行程"
        }
        
        // 使用第一个事件的标题
        return firstEvent.title
    }
    
    /// 打开 BlockEditView（智能行程）
    private func openBlockEditView(for event: Event) {
        // 保存事件ID，用于后续保存时匹配
        eventIdForBlockEdit = event.id
        
        // 将 Event 转换为 PlanResult
        let plan = convertEventsToPlanResult(events: eventsToView)
        planForBlockEdit = plan
        
        // 找到对应的 Block
        if let block = findBlockForEvent(event, in: plan) {
            blockToEdit = block
            showBlockEditView = true
        } else {
            // 如果找不到对应的 Block，创建一个新的
            let calendar = Calendar.current
            let startTime = event.startDateTime ?? Date()
            let endTime = event.endDateTime ?? event.startDateTime ?? Date()
            
            let newBlock = TimeBlock(
                type: .activity,
                startTime: startTime,
                endTime: endTime,
                title: event.title,
                location: event.destination,
                isAnchor: false,
                priority: 5,
                description: event.information
            )
            blockToEdit = newBlock
            showBlockEditView = true
        }
    }
    
    /// 将 Events 转换为 PlanResult
    private func convertEventsToPlanResult(events: [Event]) -> PlanResult {
        let calendar = Calendar.current
        var dayPlans: [DayPlan] = []
        
        // 按日期分组
        let groupedByDate = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.dateObj ?? Date())
        }
        
        for (date, dayEvents) in groupedByDate.sorted(by: { $0.key < $1.key }) {
            var blocks: [TimeBlock] = []
            
            for event in dayEvents.sorted(by: { ($0.startDateTime ?? Date()) < ($1.startDateTime ?? Date()) }) {
                let block = TimeBlock(
                    type: .activity,
                    startTime: event.startDateTime ?? date,
                    endTime: event.endDateTime ?? event.startDateTime ?? date,
                    title: event.title,
                    location: event.destination,
                    isAnchor: false,
                    priority: 5,
                    description: event.information
                )
                blocks.append(block)
            }
            
            dayPlans.append(DayPlan(date: date, blocks: blocks))
        }
        
        return PlanResult(days: dayPlans, assumptions: [], riskFlags: [])
    }
    
    /// 找到 Event 对应的 Block
    private func findBlockForEvent(_ event: Event, in plan: PlanResult) -> TimeBlock? {
        for dayPlan in plan.days {
            for block in dayPlan.blocks {
                if block.title == event.title &&
                   block.location == event.destination {
                    return block
                }
            }
        }
        return nil
    }
    
    /// 更新 Plan 中的 Block 并同步到 Event
    private func updateBlockInPlan(_ updatedBlock: TimeBlock) {
        guard let eventId = eventIdForBlockEdit else {
            print("⚠️ 无法更新：缺少事件ID")
            return
        }
        
        // 在 allEvents 中找到对应的事件
        guard let eventIndex = allEvents.firstIndex(where: { $0.id == eventId }) else {
            print("⚠️ 无法找到要更新的事件: eventId=\(eventId)")
            return
        }
        
        // 更新 Event
        var updatedEvent = allEvents[eventIndex]
        updatedEvent.title = updatedBlock.title
        updatedEvent.destination = updatedBlock.location ?? ""
        updatedEvent.information = updatedBlock.description
        
        // 更新时间
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        updatedEvent.date = dateFormatter.string(from: updatedBlock.startTime)
        updatedEvent.startTime = timeFormatter.string(from: updatedBlock.startTime)
        updatedEvent.endTime = timeFormatter.string(from: updatedBlock.endTime)
        
        // 立即更新本地状态（UI 立即响应）
        allEvents[eventIndex] = updatedEvent
        
        // 更新本地缓存
        EventCacheManager.shared.updateEventInCache(updatedEvent, for: userManager.userOpenId)
        
        // 后台异步保存到 Firebase
        Task {
            do {
                try await EventManager.shared.updateEvent(event: updatedEvent)
                print("✅ 智能行程更新成功: \(updatedEvent.title)")
                
                // 刷新事件列表
                await refreshEvents()
            } catch {
                print("⚠️ 更新事件失败: \(error.localizedDescription)")
                // 即使 Firebase 更新失败，本地缓存已更新，用户可以继续使用
            }
        }
    }
    
    /// 保存模板视图
    private var saveTemplateView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("保存行程模板")
                    .font(.headline)
                    .padding()
                
                Button("確認保存") {
                    saveAsTemplate()
                    showSaveTemplateSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("儲存模板")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showSaveTemplateSheet = false
                    }
                }
                #endif
            }
        }
    }
    
    /// 打开 PlanEditView 编辑选中的行程
    private func openPlanEditView() {
        // 获取选中的事件
        let selectedEvents = eventsToView.filter { event in
            guard let eventId = event.id else { return false }
            return selectedEventIds.contains(eventId)
        }
        
        // 保存原始事件ID列表（用于更新）
        originalEventIdsForEdit = selectedEvents.compactMap { $0.id }
        
        // 转换为 PlanResult
        let plan = convertEventsToPlanResult(events: selectedEvents)
        planToEdit = plan
        showPlanEditView = true
    }
    
    /// 保存为模板（无参数版本）
    private func saveAsTemplate() {
        let plan = convertEventsToPlanResult(events: eventsToView)
        let title = generateTripTitle()
        saveAsTemplateWithParams(plan: plan, title: title)
    }
    
    /// 保存为模板（带参数）
    private func saveAsTemplateWithParams(plan: PlanResult, title: String) {
        let template = SavedTripTemplate(
            title: title,
            plan: plan,
            savedDate: Date(),
            tags: [],
            destination: extractDestination()
        )
        
        TripTemplateManager.shared.saveTemplate(template, for: userManager.userOpenId, syncToAppleCalendar: false)
        
        // 显示成功提示
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            let alert = UIAlertController(title: "成功", message: "已轉存為行程模板：\(title)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            rootViewController.present(alert, animated: true)
        }
        #endif
    }
    
    /// 提取目的地
    private func extractDestination() -> String {
        if let firstEvent = eventsToView.first, !firstEvent.destination.isEmpty {
            return firstEvent.destination
        }
        return "未知目的地"
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: Event
    let currentUserId: String
    var showEditButton: Bool = false  // 是否显示编辑按钮
    var onEditTap: (() -> Void)? = nil  // 编辑按钮点击回调
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧：图标圆圈
            ZStack {
                Circle()
                    .fill(iconColorForEvent(event))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconForEvent(event))
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            // 中间：标题和时间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                // 时间和类型标签
                if let start = event.startDateTime {
                    HStack(spacing: 4) {
                        Text(timeFormatter.string(from: start))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(iconColorForEvent(event))
                        
                        Text("·")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        Text(typeLabelForEvent(event))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 右侧：编辑按钮（仅在需要时显示）
            if showEditButton {
                Button(action: {
                    onEditTap?()
                }) {
                    Text("編輯")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 根据事件类型和内容判断图标颜色
    private func iconColorForEvent(_ event: Event) -> Color {
        let title = event.title.lowercased()
        let destination = event.destination.lowercased()
        
        // 交通类型：灰色或浅蓝色
        if title.contains("搭乘") || title.contains("地鐵") || title.contains("地鐵") || 
           title.contains("subway") || title.contains("bus") || title.contains("train") ||
           title.contains("交通") || title.contains("transport") {
            return Color(red: 0.7, green: 0.8, blue: 0.9)  // 浅蓝色
        }
        
        // 餐厅类型：橙色
        if title.contains("餐廳") || title.contains("餐廳") || title.contains("燒肉") ||
           title.contains("restaurant") || title.contains("food") || title.contains("dining") ||
           title.contains("美食") || title.contains("午餐") || title.contains("晚餐") {
            return .orange
        }
        
        // 购物类型：蓝色
        if title.contains("購物") || title.contains("逛街") || title.contains("shopping") ||
           title.contains("mall") || title.contains("store") {
            return .blue
        }
        
        // 景点类型：蓝色
        if title.contains("寺") || title.contains("神社") || title.contains("神宮") ||
           title.contains("temple") || title.contains("attraction") || title.contains("景點") {
            return .blue
        }
        
        // 默认：根据访问来源确定颜色
        let now = Date()
        if let end = event.endDateTime, now > end {
            return .gray
        }
        
        if event.creatorOpenid == currentUserId {
            return .blue  // 自己创建的默认蓝色
        } else if let groupId = event.groupId, !groupId.isEmpty {
            return .blue  // 社群活动
        } else {
            return .green  // 好友/分享
        }
    }
    
    // 根据事件类型和内容判断图标
    private func iconForEvent(_ event: Event) -> String {
        let title = event.title.lowercased()
        let destination = event.destination.lowercased()
        
        // 交通类型
        if title.contains("搭乘") || title.contains("地鐵") || title.contains("subway") ||
           title.contains("bus") || title.contains("train") || title.contains("交通") {
            return "tram.fill"
        }
        
        // 餐厅类型
        if title.contains("餐廳") || title.contains("燒肉") || title.contains("restaurant") ||
           title.contains("food") || title.contains("dining") || title.contains("美食") {
            return "fork.knife"
        }
        
        // 购物类型
        if title.contains("購物") || title.contains("逛街") || title.contains("shopping") {
            return "bag.fill"
        }
        
        // 景点类型（寺庙、神社等）
        if title.contains("寺") || title.contains("神社") || title.contains("神宮") ||
           title.contains("temple") || title.contains("attraction") {
            return "building.columns.fill"
        }
        
        // 默认图标
        return "mappin.circle.fill"
    }
    
    // 根据事件类型返回类型标签
    private func typeLabelForEvent(_ event: Event) -> String {
        let title = event.title.lowercased()
        
        if title.contains("搭乘") || title.contains("地鐵") || title.contains("subway") ||
           title.contains("bus") || title.contains("train") || title.contains("交通") {
            return "交通"
        }
        
        if title.contains("餐廳") || title.contains("燒肉") || title.contains("restaurant") ||
           title.contains("food") || title.contains("dining") || title.contains("美食") {
            return "餐廳"
        }
        
        if title.contains("購物") || title.contains("逛街") || title.contains("shopping") {
            return "購物"
        }
        
        if title.contains("寺") || title.contains("神社") || title.contains("神宮") ||
           title.contains("temple") || title.contains("attraction") || title.contains("景點") {
            return "景點"
        }
        
        return "活動"
    }
}

// MARK: - Formatters

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M月d日（E）"
    return f
}()

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()

private let dayDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M月d日（E）"
    f.locale = Locale(identifier: "zh_TW")
    return f
}()

// MARK: - 拖拽代理
struct EventDropDelegate: DropDelegate {
    let event: Event
    let dayDate: Date
    let dayIndex: Int
    @Binding var eventsByDate: [(Date, [Event])]
    @Binding var draggedEvent: Event?
    let onMove: (Int, Int, Int, Int) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggedEvent = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedEvent = draggedEvent,
              let draggedEventId = draggedEvent.id,
              let currentEventId = event.id,
              draggedEventId != currentEventId else { return }
        
        guard let draggedDayIndex = eventsByDate.firstIndex(where: { $0.1.contains(where: { $0.id == draggedEventId }) }),
              let draggedIndex = eventsByDate[draggedDayIndex].1.firstIndex(where: { $0.id == draggedEventId }),
              let currentIndex = eventsByDate[dayIndex].1.firstIndex(where: { $0.id == currentEventId }) else { return }
        
        if draggedDayIndex == dayIndex {
            // 同一天内移动
            if draggedIndex < currentIndex {
                onMove(draggedIndex, currentIndex + 1, draggedDayIndex, dayIndex)
            } else {
                onMove(draggedIndex, currentIndex, draggedDayIndex, dayIndex)
            }
        } else {
            // 跨日期移动：移动到目标日期的当前位置
            onMove(draggedIndex, currentIndex, draggedDayIndex, dayIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - 滚动位置数据结构
struct ScrollOffsetData: Equatable {
    let index: Int
    let offset: CGFloat
}

// MARK: - 滚动位置偏好键
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [ScrollOffsetData] = []
    
    static func reduce(value: inout [ScrollOffsetData], nextValue: () -> [ScrollOffsetData]) {
        value.append(contentsOf: nextValue())
    }
}
