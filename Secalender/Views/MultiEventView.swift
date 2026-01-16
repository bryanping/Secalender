//
//  MultiEventView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import Foundation

struct MultiEventView: View {
    let eventIds: [Int]
    @Binding var allEvents: [Event]  // 改为 Binding，可以实时更新
    var onComplete: (() -> Void)? = nil
    var onRefreshEvents: (() async -> Void)? = nil  // 刷新事件列表的回调
    var onDismiss: (() -> Void)? = nil  // 关闭页面时的回调（用于刷新和重置状态）
    
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    // 本地状态：已删除的事件ID（软删除后从列表中移除）
    @State private var deletedEventIds: Set<Int> = []
    // 全部删除确认对话框
    @State private var showDeleteAllConfirmation = false
    
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题区域
                VStack(alignment: .leading, spacing: 8) {
                    Text("多行程檢視")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if !eventsToView.isEmpty {
                        Text("共 \(eventsToView.count) 個行程")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // 行程列表
                if eventsToView.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("所有行程已删除")
                            .font(.headline)
                        Text("已删除的行程不会显示在此列表中")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(eventsToView, id: \.id) { event in
                        NavigationLink(destination: EventEditView(
                            viewModel: EventDetailViewModel(event: event),
                            onComplete: {
                                // 更新后刷新列表并返回多行程页面
                                Task {
                                    await refreshEvents()
                                }
                            },
                            onDelete: {
                                // 删除后从列表中移除（软删除）并返回多行程页面
                                if let eventId = event.id {
                                    withAnimation {
                                        deletedEventIds.insert(eventId)
                                    }
                                }
                                Task {
                                    await refreshEvents()
                                }
                            },
                            source: .multiView
                        )
                        .onDisappear {
                            // 编辑页面关闭时，通知父视图可能需要刷新
                            // 注意：这里不直接调用 onDismiss，因为用户可能只是返回多行程页面，不是关闭整个 MultiEventView
                        }) {
                            EventCard(event: event, currentUserId: userManager.userOpenId)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle("多行程检视")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !eventsToView.isEmpty {
                    Button(role: .destructive) {
                        showDeleteAllConfirmation = true
                    } label: {
                        Label("全部删除", systemImage: "trash")
                    }
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAllConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await deleteAllEvents()
                }
            }
        } message: {
            Text("已选择的 \(eventsToView.count) 个行程将被全部删除，此操作无法撤销。")
        }
        .onDisappear {
            // 当页面关闭时，通知父视图刷新并重置状态
            onDismiss?()
        }
    }
    
    /// 刷新事件列表
    private func refreshEvents() async {
        // 调用外部刷新回调，重新加载事件
        await onRefreshEvents?()
        // 由于 allEvents 是 Binding，CalendarView 更新后会自动反映到这里
    }
    
    /// 删除所有行程（软删除）
    private func deleteAllEvents() async {
        let eventsToDelete = eventsToView
        
        // 批量软删除所有行程
        await withTaskGroup(of: Void.self) { group in
            for event in eventsToDelete {
                guard let eventId = event.id else { continue }
                group.addTask {
                    do {
                        try await EventManager.shared.softDeleteEvent(eventId: eventId)
                    } catch {
                        print("删除行程失败 (ID: \(eventId)): \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 将所有行程添加到已删除列表
        await MainActor.run {
            for event in eventsToDelete {
                if let eventId = event.id {
                    deletedEventIds.insert(eventId)
                }
            }
        }
        
        // 刷新事件列表
        await refreshEvents()
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: Event
    let currentUserId: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和时间
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // 日期和时间
                    HStack(spacing: 12) {
                        if let start = event.startDateTime {
                            Label(timeFormatter.string(from: start), systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let dateObj = event.dateObj {
                            Label(dateFormatter.string(from: dateObj), systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // 颜色指示器
                Circle()
                    .fill(determineEventColor(for: event))
                    .frame(width: 12, height: 12)
            }
            
            // 地点
            if !event.destination.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(event.destination)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // 备注
            if let information = event.information, !information.isEmpty {
                Text(information)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func determineEventColor(for event: Event) -> Color {
        let now = Date()
        
        // 已结束：灰色
        if let end = event.endDateTime, now > end {
            return .gray
        }
        
        // 根据访问来源确定颜色
        if event.creatorOpenid == currentUserId {
            return .red      // 自己创建
        } else if let groupId = event.groupId, !groupId.isEmpty {
            return .blue     // 社群活动
        } else {
            return .green    // 好友/分享
        }
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
