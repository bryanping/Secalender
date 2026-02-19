//
//  ImportAppleCalendarView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import EventKit
import Foundation

struct ImportAppleCalendarView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var calendarManager = AppleCalendarManager.shared
    @State private var appleEvents: [EKEvent] = []
    @State private var selectedEventIds: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var importSuccessCount = 0
    @State private var importFailCount = 0
    @State private var showImportResult = false
    @State private var importedEventIds: Set<String> = []
    @State private var autoImportEnabled = false
    
    /// 啟用自動導入時按鈕為「執行導入行程」，否則為「導入選中事件」
    private var importButtonTitle: String {
        autoImportEnabled ? "执行导入行程" : "导入选中事件 (\(selectedEventIds.count))"
    }
    
    /// 自動導入模式：可執行；手動模式：需有選中事件
    private var isImportButtonEnabled: Bool {
        autoImportEnabled ? true : !selectedEventIds.isEmpty
    }
    
    // 日期範圍：開始日期從當天，結束日期為開始日期往後一個月
    @State private var startDate: Date = Date()
    @State private var endDate: Date = (Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 日期范围选择器和自动导入开关
                VStack(spacing: 12) {
                    // 自动导入开关
                    HStack {
                        Toggle("自动导入新事件", isOn: $autoImportEnabled)
                            .tint(.blue)
                            .onChange(of: autoImportEnabled) { oldValue, newValue in
                                Task {
                                    try? await UserPreferencesManager.shared.setAutoImportAppleCalendar(newValue, for: userManager.userOpenId)
                                }
                            }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    Button(action: {
                        Task {
                            await loadAppleEvents()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("刷新事件")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if appleEvents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("未找到事件")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("请选择其他日期范围或检查日历权限")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(appleEvents, id: \.eventIdentifier) { event in
                            EventRowView(
                                event: event,
                                isSelected: selectedEventIds.contains(event.eventIdentifier ?? ""),
                                isImported: event.eventIdentifier != nil && importedEventIds.contains(event.eventIdentifier!),
                                onToggle: {
                                    if let identifier = event.eventIdentifier {
                                        if selectedEventIds.contains(identifier) {
                                            selectedEventIds.remove(identifier)
                                        } else {
                                            selectedEventIds.insert(identifier)
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
                
                // 底部操作栏
                if !appleEvents.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            Button("全选") {
                                selectedEventIds = Set(appleEvents.compactMap { $0.eventIdentifier })
                            }
                            .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text("已选择 \(selectedEventIds.count) 个事件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("取消全选") {
                                selectedEventIds.removeAll()
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            Task {
                                await importSelectedEvents()
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text(importButtonTitle)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isImportButtonEnabled ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!isImportButtonEnabled)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("从 Apple 日历导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .task {
                // 載入自動導入設定
                autoImportEnabled = UserPreferencesManager.shared.getAutoImportAppleCalendar(for: userManager.userOpenId)
                
                // 初始化日期：開始＝當天，結束＝開始＋一個月
                let today = Date()
                startDate = today
                endDate = Calendar.current.date(byAdding: .month, value: 1, to: today) ?? today
                
                // 載入已導入的事件ID（只從本地）
                loadImportedEventIds()
                
                // 請求權限並載入事件
                await requestPermissionAndLoadEvents()
            }
            .alert("导入结果", isPresented: $showImportResult) {
                Button("确定") {
                    if importSuccessCount > 0 {
                        dismiss()
                    }
                }
            } message: {
                Text("成功导入 \(importSuccessCount) 个事件\n失败 \(importFailCount) 个事件")
            }
            .alert("错误", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    /// 加载已导入的事件ID（只从本地加载）
    @MainActor
    private func loadImportedEventIds() {
        importedEventIds = AppleCalendarImportManager.shared.getAllImportedEventIds(for: userManager.userOpenId)
    }
    
    /// 请求权限并加载事件
    @MainActor
    private func requestPermissionAndLoadEvents() async {
        isLoading = true
        errorMessage = nil
        
        // 请求权限
        await withCheckedContinuation { continuation in
            calendarManager.requestAccessIfNeeded { granted in
                if !granted {
                    errorMessage = "需要日历权限才能导入事件，请前往设置开启"
                    showErrorAlert = true
                    isLoading = false
                    continuation.resume()
                    return
                }
                continuation.resume()
            }
        }
        
        // 加载事件
        await loadAppleEvents()
    }
    
    /// 加载 Apple 日历事件
    @MainActor
    private func loadAppleEvents() async {
        isLoading = true
        errorMessage = nil
        
        // 确保结束日期不早于开始日期
        if endDate < startDate {
            endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        }
        
        let events = await calendarManager.fetchEventsAsync(startDate: startDate, endDate: endDate)
        
        // 过滤掉已过期的事件（可选，根据需求决定）
        let now = Date()
        let filteredEvents = events.filter { event in
            guard let endDate = event.endDate else { return true }
            return endDate >= now || event.isAllDay
        }
        
        // 过滤掉已导入的事件（但保留在列表中显示，只是标记为已导入）
        appleEvents = filteredEvents
        
        isLoading = false
    }
    
    /// 導入事件：自動導入模式導入範圍內所有未導入，手動模式導入選中事件
    @MainActor
    private func importSelectedEvents() async {
        let eventsToImport: [EKEvent]
        if autoImportEnabled {
            // 自動導入：導入日期範圍內所有未導入的事件
            eventsToImport = appleEvents.filter { event in
                guard let identifier = event.eventIdentifier else { return false }
                return !importedEventIds.contains(identifier)
            }
        } else {
            guard !selectedEventIds.isEmpty else { return }
            eventsToImport = appleEvents.filter { event in
                guard let identifier = event.eventIdentifier else { return false }
                return selectedEventIds.contains(identifier)
            }
        }
        
        guard !eventsToImport.isEmpty else {
            if autoImportEnabled {
                showImportResult = true
                importSuccessCount = 0
                importFailCount = 0
            }
            return
        }
        
        isLoading = true
        importSuccessCount = 0
        importFailCount = 0
        
        var importResults: [(appleEventId: String, appEventId: Int?)] = []
        
        for ekEvent in eventsToImport {
            guard let appleEventId = ekEvent.eventIdentifier else { continue }
            
            // 检查是否已导入
            if AppleCalendarImportManager.shared.isEventImported(appleEventId: appleEventId, for: userManager.userOpenId) {
                print("⚠️ 事件已导入，跳过: \(ekEvent.title ?? "未知")")
                continue
            }
            
            // 转换为应用事件格式
            let event = convertEKEventToEvent(ekEvent)
            
            // 只保存到本地缓存，不保存到 Firebase
            EventCacheManager.shared.addEventToCache(event, for: userManager.userOpenId)
            
            // 标记为已导入（只保存在本地）
            importResults.append((appleEventId: appleEventId, appEventId: event.id))
            importSuccessCount += 1
            
            print("✅ 导入成功（仅本地）: \(ekEvent.title ?? "未知")")
        }
        
        // 批量标记为已导入（只保存在本地）
        if !importResults.isEmpty {
            AppleCalendarImportManager.shared.markEventsAsImported(
                events: importResults,
                for: userManager.userOpenId
            )
            // 更新本地已导入列表
            loadImportedEventIds()
        }
        
        isLoading = false
        showImportResult = true
        
        // 刷新事件列表
        if importSuccessCount > 0 {
            NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
        }
    }
    
    /// 将 EKEvent 转换为 Event
    private func convertEKEventToEvent(_ ekEvent: EKEvent) -> Event {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let startDate = ekEvent.startDate ?? Date()
        let endDate = ekEvent.endDate ?? startDate
        
        let dateString = dateFormatter.string(from: startDate)
        let startTimeString: String
        let endTimeString: String
        let isAllDay: Bool
        
        if ekEvent.isAllDay {
            isAllDay = true
            startTimeString = "00:00:00"
            endTimeString = "23:59:59"
        } else {
            isAllDay = false
            startTimeString = timeFormatter.string(from: startDate)
            endTimeString = timeFormatter.string(from: endDate)
        }
        
        // 处理跨日事件
        let endDateString: String?
        if !ekEvent.isAllDay && !Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            endDateString = dateFormatter.string(from: endDate)
        } else {
            endDateString = nil
        }
        
        // 构建备注信息
        var information = ""
        if let notes = ekEvent.notes, !notes.isEmpty {
            information = notes
        }
        if let location = ekEvent.location, !location.isEmpty {
            if !information.isEmpty {
                information += "\n\n"
            }
            information += "地点：\(location)"
        }
        
        let createTimeFormatter = DateFormatter()
        createTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // 使用 Apple 日曆識別符標記為外部匯入
        let calendarComp = ekEvent.calendar?.calendarIdentifier ?? "apple"
        
        return Event(
            title: ekEvent.title ?? "未命名事件",
            creatorOpenid: userManager.userOpenId,
            color: "#FF6280",
            date: dateString,
            startTime: startTimeString,
            endTime: endTimeString,
            endDate: endDateString,
            destination: ekEvent.location ?? "",
            mapObj: "",
            openChecked: 0,
            personChecked: 0,
            createTime: createTimeFormatter.string(from: Date()),
            information: information.isEmpty ? nil : information,
            isAllDay: isAllDay,
            repeatType: "never",
            calendarComponent: calendarComp
        )
    }
}

// MARK: - EventRowView
struct EventRowView: View {
    let event: EKEvent
    let isSelected: Bool
    let isImported: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 选择框
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 24))
                
                VStack(alignment: .leading, spacing: 4) {
                    // 标题和已导入标记
                    HStack {
                        Text(event.title ?? "未命名事件")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if isImported {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                Text("已导入")
                                    .font(.caption)
                            }
                            .foregroundColor(.green)
                        }
                    }
                    
                    // 时间
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatEventTime(event))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 地点
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatEventTime(_ event: EKEvent) -> String {
        let dateFormatter = DateFormatter()
        
        if event.isAllDay {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let startDate = event.startDate {
                if let endDate = event.endDate, endDate > startDate {
                    let endDateString = dateFormatter.string(from: endDate)
                    let startDateString = dateFormatter.string(from: startDate)
                    if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
                        return startDateString
                    } else {
                        return "\(startDateString) - \(endDateString)"
                    }
                } else {
                    return dateFormatter.string(from: startDate)
                }
            }
            return "全天"
        } else {
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            if let startDate = event.startDate, let endDate = event.endDate {
                let startString = dateFormatter.string(from: startDate)
                if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm"
                    return "\(startString) - \(timeFormatter.string(from: endDate))"
                } else {
                    let endString = dateFormatter.string(from: endDate)
                    return "\(startString) - \(endString)"
                }
            }
        }
        return ""
    }
}
