//
//  PlanEditView.swift
//  Secalender
//
//  行程编辑页面 - 基于 EventCreateView 的多行程编辑功能
//

import SwiftUI
import Foundation
import MapKit
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Date 扩展：验证日期有效性
extension Date {
    var isValid: Bool {
        // 检查日期是否在合理范围内（1900-2100年）
        let calendar = Calendar.current
        let year = calendar.component(.year, from: self)
        return year >= 1900 && year <= 2100
    }
}

struct PlanEditView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    let plan: PlanResult
    var customTitle: String? = nil  // 用户自定义标题（来自"此行的主題"）
    var originalEventIds: [Int]? = nil  // 原始事件ID列表（用于更新现有事件）
    var onSaveToCalendar: (([Int]) -> Void)? = nil  // 修改：传递保存后的事件ID列表
    var onSaveToTemplate: ((PlanResult, String?) -> Void)? = nil  // 修改：传回编辑后的 PlanResult 和标题
    var onDismiss: (() -> Void)? = nil
    
    @StateObject private var formState = EventFormState()
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var activeSheet: EventSheetType? = nil
    @State private var tripStartDate: Date = Date()  // 行程开始日期
    @State private var originalBlocksByDay: [Date: [TimeBlock]] = [:]  // 保存原始的所有 blocks（包括 transit, buffer, flex, rest）
    
    @State private var templateTitle: String = ""     // 模版標題（儲存模板時使用，與行程1分離）
    @State private var firstDayTitle: String = ""    // 行程1的標題（第一個行程卡片的標題）
    @State private var isDataLoaded = false          // 行程資料是否已非同步載入完成
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isDataLoaded {
                    formContent
                } else {
                    loadingView
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("編輯行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        hideKeyboard()
                        onDismiss?()
                        dismiss()
                    }
                }
            }
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("好") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(item: $activeSheet) { sheetType in
                switch sheetType {
                case .locationPicker:
                    LocationPickerView(
                        selectedAddress: Binding(
                            get: {
                                if let itemId = formState.showLocationPickerForItem,
                                   let item = formState.multiDayItems.first(where: { $0.id == itemId }) {
                                    return item.destination
                                }
                                return ""
                            },
                            set: { newValue in
                                if let itemId = formState.showLocationPickerForItem,
                                   let index = formState.multiDayItems.firstIndex(where: { $0.id == itemId }) {
                                    formState.multiDayItems[index].destination = newValue
                                }
                            }
                        ),
                        selectedCoordinate: Binding(
                            get: {
                                if let itemId = formState.showLocationPickerForItem,
                                   let item = formState.multiDayItems.first(where: { $0.id == itemId }) {
                                    return item.coordinate
                                }
                                return nil
                            },
                            set: { newValue in
                                if let itemId = formState.showLocationPickerForItem,
                                   let index = formState.multiDayItems.firstIndex(where: { $0.id == itemId }) {
                                    formState.multiDayItems[index].coordinate = newValue
                                }
                            }
                        )
                    )
                    .onDisappear {
                        activeSheet = nil
                        formState.showLocationPickerForItem = nil
                    }
                default:
                    EmptyView()
                }
            }
            .onAppear {
                loadPlanDataAsync()
            }
        }
    }
    
    // MARK: - 載入中視圖
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("載入行程中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 表單內容
    private var formContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                        // 模版标题（與行程1標題分離，僅用於儲存模板時的名稱）
                        EventFormCard(icon: "textformat", title: "模版標題", iconColor: .blue) {
                            TextField("例如:東京5日深度遊", text: $templateTitle)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(UIColor.systemGray6))
                                )
                        }
                        
                        // 行程日期选择器
                        EventFormCard(icon: "calendar", title: "行程日期", iconColor: .green) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("plan_edit.start_date".localized())
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                DatePicker(
                                    "開始日期",
                                    selection: $tripStartDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.compact)
                                .onChange(of: tripStartDate) { oldValue, newValue in
                                    // 更新所有行程项的日期
                                    updateAllDates(startDate: newValue)
                                }
                            }
                        }
                        
                        // 多日行程编辑区域（每个行程显示为卡片）
                        if formState.isMultiDayEvent {
                            ForEach(Array(formState.multiDayItems.enumerated()), id: \.element.id) { index, item in
                                MultiDayEventItemView(
                                    index: index,
                                    item: item,
                                    items: $formState.multiDayItems,
                                    mainTitle: $firstDayTitle,
                                    isCalculatingTravelTime: false,
                                    showLocationPickerForItem: $formState.showLocationPickerForItem,
                                    activeSheet: $activeSheet,
                                    onCoordinateChanged: {},
                                    onStartTimeChanged: {},
                                    showDeleteButton: formState.multiDayItems.count > 1,
                                    onDelete: formState.multiDayItems.count > 1 ? { deleteTrip(at: index) } : nil
                                )
                            }
                            
                            // 添加行程按钮（不限制数量）
                            Button(action: {
                                withAnimation {
                                    // 如果已有行程，設置默認時間為上一個行程開始時間後15分鐘
                                    if let lastItem = formState.multiDayItems.last {
                                        let calendar = Calendar.current
                                        let newStartTime = calendar.date(byAdding: .minute, value: 15, to: lastItem.startTime) ?? Date()
                                        var newItem = MultiDayEventItem()
                                        newItem.date = lastItem.date
                                        newItem.startTime = newStartTime
                                        newItem.endTime = newStartTime
                                        newItem.isHasEnd = false
                                        formState.multiDayItems.append(newItem)
                                    } else {
                                        var newItem = MultiDayEventItem()
                                        newItem.date = tripStartDate
                                        newItem.startTime = tripStartDate
                                        newItem.endTime = tripStartDate
                                        newItem.isHasEnd = false
                                        formState.multiDayItems.append(newItem)
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18))
                                    Text("plan_edit.add_trip".localized())
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                        .foregroundColor(.blue.opacity(0.3))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                        
                        // 底部按钮区域
                        VStack(spacing: 12) {
                            // 保存模版按钮
                            Button(action: {
                                hideKeyboard()
                                saveToTemplate()
                            }) {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                    Text("plan_edit.save_template".localized())
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            // 发布行程按钮（将行程加入行事历）
                            Button(action: {
                                hideKeyboard()
                                saveToCalendar()
                            }) {
                                HStack {
                                    Image(systemName: "calendar.badge.plus")
                                    Text("plan_edit.publish_trip".localized())
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
            }
            .padding(.vertical)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
    
    // MARK: - 刪除行程
    private func deleteTrip(at index: Int) {
        guard index >= 0, index < formState.multiDayItems.count, formState.multiDayItems.count > 1 else { return }
        withAnimation {
            formState.multiDayItems.remove(at: index)
        }
    }
    
    // MARK: - 更新所有日期
    private func updateAllDates(startDate: Date) {
        let calendar = Calendar.current
        
        // 按日期分组，保持同一天的活动在同一天
        var currentDayDate: Date? = nil
        var dayOffset: Int = 0
        
        for (index, _) in formState.multiDayItems.enumerated() {
            let item = formState.multiDayItems[index]
            let itemDayStart = calendar.startOfDay(for: item.date)
            
            // 如果这是新的一天，更新 dayOffset
            if let previousDayDate = currentDayDate {
                if itemDayStart != calendar.startOfDay(for: previousDayDate) {
                    dayOffset += 1
                }
            } else {
                // 第一个项目
                dayOffset = 0
            }
            
            currentDayDate = itemDayStart
            
            // 根据开始日期和 dayOffset 计算新日期
            if let newDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                formState.multiDayItems[index].date = newDate
                // 同时更新开始时间和结束时间的日期部分
                let startTimeComponents = calendar.dateComponents([.hour, .minute], from: item.startTime)
                if let newStartTime = calendar.date(bySettingHour: startTimeComponents.hour ?? 0, minute: startTimeComponents.minute ?? 0, second: 0, of: newDate) {
                    formState.multiDayItems[index].startTime = newStartTime
                }
                if item.isHasEnd {
                    let endTimeComponents = calendar.dateComponents([.hour, .minute], from: item.endTime)
                    if let newEndTime = calendar.date(bySettingHour: endTimeComponents.hour ?? 0, minute: endTimeComponents.minute ?? 0, second: 0, of: newDate) {
                        formState.multiDayItems[index].endTime = newEndTime
                    }
                }
            }
        }
    }
    
    // MARK: - 非同步載入行程
    /// 先顯示頁面與載入中狀態，再於背景完成資料轉換，避免被誤認為當機
    private func loadPlanDataAsync() {
        guard !plan.days.isEmpty else {
            errorMessage = "行程数据无效：没有行程天数"
            showErrorAlert = true
            return
        }
        Task { @MainActor in
            // 在主線程執行 plan 轉換（computePlanInitialData 為 MainActor 隔離）
            let result = computePlanInitialData()
            applyPlanInitialData(result)
            isDataLoaded = true
        }
    }
    
    /// 背景執行：將 plan 轉為初始化所需資料（不觸碰 UI 狀態，僅讀取 plan / customTitle）
    private func computePlanInitialData() -> (titles: (String, String), tripStartDate: Date, items: [MultiDayEventItem], blocksByDay: [Date: [TimeBlock]]) {
        let planData = plan
        let customTitleValue = customTitle
        
        // 設置模版標題與行程1標題（兩者獨立，初始值可相同）
        let initialTitle: String
        if let ct = customTitleValue, !ct.isEmpty {
            initialTitle = ct
        } else {
            let destination: String
            if let firstDay = planData.days.first,
               let firstBlock = firstDay.blocks.first(where: { $0.type == .activity }),
               let location = firstBlock.location {
                destination = location.contains(" - ") ? String(location.split(separator: " - ").last ?? "") : location
            } else {
                destination = "行程"
            }
            initialTitle = "\(destination) \(planData.days.count)天行程"
        }
        
        let startDate: Date
        if let firstDay = planData.days.first {
            startDate = firstDay.date
        } else {
            startDate = Date()
        }
        
        var items: [MultiDayEventItem] = []
        let calendar = Calendar.current
        var blocksByDay: [Date: [TimeBlock]] = [:]
        
        for (dayIndex, day) in planData.days.enumerated() {
            let dayDate: Date
            if let calculatedDate = calendar.date(byAdding: .day, value: dayIndex, to: startDate) {
                dayDate = calculatedDate
            } else {
                dayDate = day.date.isValid ? day.date : Date()
            }
            
            var adjustedBlocks: [TimeBlock] = []
            for block in day.blocks {
                let startTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: block.startTime)
                let endTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: block.endTime)
                
                let adjustedStartTime = calendar.date(bySettingHour: startTimeComponents.hour ?? 0, minute: startTimeComponents.minute ?? 0, second: startTimeComponents.second ?? 0, of: dayDate) ?? dayDate
                let adjustedEndTime = calendar.date(bySettingHour: endTimeComponents.hour ?? 0, minute: endTimeComponents.minute ?? 0, second: endTimeComponents.second ?? 0, of: dayDate) ?? dayDate
                
                let adjustedBlock = TimeBlock(
                    type: block.type,
                    startTime: adjustedStartTime,
                    endTime: adjustedEndTime,
                    title: block.title,
                    location: block.location,
                    isAnchor: block.isAnchor,
                    priority: block.priority,
                    description: block.description
                )
                adjustedBlocks.append(adjustedBlock)
            }
            blocksByDay[dayDate] = adjustedBlocks
            
            // 获取当天的所有活动（过滤掉 transit、buffer 等），并按开始时间排序
            let activities = day.blocks
                .filter { $0.type == .activity }
                .sorted(by: { 
                    // 安全排序，避免无效日期导致崩溃
                    let start1 = $0.startTime
                    let start2 = $1.startTime
                    return start1 < start2
                })
            
            // 如果没有活动，创建一个默认项
            if activities.isEmpty {
                var item = MultiDayEventItem()
                item.date = dayDate  // 使用该天的日期
                item.startTime = dayDate
                item.endTime = dayDate
                item.information = "行程安排"
                item.isHasEnd = false
                items.append(item)
            } else {
                // 为每个活动创建一个项（不限制数量）
                // 同一天的所有活动使用相同的日期（dayDate）
                for (activityIndex, activity) in activities.enumerated() {
                    var item = MultiDayEventItem()
                    // 第一个行程（dayIndex == 0 && activityIndex == 0）的标题使用主标题（customTitle）
                    // 其他行程使用各自的 activity.title
                    if dayIndex == 0 && activityIndex == 0 {
                        // 第一个行程：使用主标题（用户填写的"此行的主題"），item.title 留空，因为会显示 mainTitle
                        item.title = ""  // 留空，因为 MultiDayEventItemView 在 index == 0 时会显示 mainTitle
                    } else {
                        // 其他行程：使用各自的标题
                        item.title = activity.title.isEmpty ? "行程活动" : activity.title
                    }
                    item.information = activity.description ?? activity.title
                    item.date = dayDate  // 同一天的所有活动使用相同的日期
                    
                    // 保持原有的时间，只更新日期部分（添加安全检查）
                    let startTime = activity.startTime.isValid ? activity.startTime : dayDate
                    let endTime = activity.endTime.isValid ? activity.endTime : dayDate
                    
                    let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
                    if let newStartTime = calendar.date(bySettingHour: startTimeComponents.hour ?? 0, minute: startTimeComponents.minute ?? 0, second: 0, of: dayDate) {
                        item.startTime = newStartTime
                    } else {
                        item.startTime = dayDate
                    }
                    
                    let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                    if let newEndTime = calendar.date(bySettingHour: endTimeComponents.hour ?? 0, minute: endTimeComponents.minute ?? 0, second: 0, of: dayDate) {
                        item.endTime = newEndTime
                    } else {
                        item.endTime = dayDate
                    }
                    
                    item.destination = activity.location ?? ""
                    item.isHasEnd = true
                    item.isAllDay = false
                    items.append(item)
                }
            }
        }
        
        return ((initialTitle, initialTitle), startDate, items, blocksByDay)
    }
    
    /// 主線程：將計算結果套用到 UI 狀態
    private func applyPlanInitialData(_ result: (titles: (String, String), tripStartDate: Date, items: [MultiDayEventItem], blocksByDay: [Date: [TimeBlock]])) {
        templateTitle = result.titles.0
        firstDayTitle = result.titles.1
        tripStartDate = result.tripStartDate
        originalBlocksByDay = result.blocksByDay
        formState.multiDayItems = result.items
        formState.isMultiDayEvent = true
    }
    
    // MARK: - 保存方法
    
    private func saveToCalendar() {
        // 驗證：行程1需有標題
        guard !firstDayTitle.isEmpty else {
            errorMessage = "請輸入行程1的標題"
            showErrorAlert = true
            return
        }
        
        // 保存到日历（类似 EventCreateView 的 saveMultiDayItems）
        let saveStartTime = dateToString(Date(), format: "yyyy-MM-dd HH:mm:ss")
        
        Task {
            var savedEventIds: [Int] = []
            let originalIds = originalEventIds ?? []
            
            for (index, item) in formState.multiDayItems.enumerated() {
                let eventTitle: String
                if index == 0 {
                    eventTitle = firstDayTitle
                } else if !item.title.isEmpty {
                    eventTitle = item.title
                } else {
                    eventTitle = "\(templateTitle.isEmpty ? firstDayTitle : templateTitle) - 行程 \(index + 1)"
                }
                
                let endTimeString: String
                if item.isHasEnd {
                    endTimeString = dateToString(item.endTime, format: "HH:mm:ss")
                } else {
                    endTimeString = dateToString(item.startTime, format: "HH:mm:ss")
                }
                
                var event = Event(
                    title: eventTitle,
                    creatorOpenid: userManager.userOpenId,
                    color: "#4285F4",
                    date: dateToString(item.date, format: "yyyy-MM-dd"),
                    startTime: dateToString(item.startTime, format: "HH:mm:ss"),
                    endTime: endTimeString,
                    destination: item.destination,
                    mapObj: "",
                    openChecked: 0,
                    personChecked: 0,
                    createTime: saveStartTime,
                    information: item.information,
                    isAllDay: item.isAllDay,
                    repeatType: "never",
                    calendarComponent: "default",
                    groupId: nil
                )
                
                if !item.isHasEnd {
                    event.endDate = nil
                }
                
                // 如果有原始事件ID，更新现有事件；否则创建新事件
                if index < originalIds.count {
                    // 更新现有事件
                    event.id = originalIds[index]
                    event.createTime = saveStartTime  // 保持原始创建时间
                    
                    // 更新本地缓存
                    EventCacheManager.shared.updateEventInCache(event, for: userManager.userOpenId)
                    
                    // 更新到 Firebase
                    do {
                        try await EventManager.shared.updateEvent(event: event)
                        if let eventId = event.id {
                            savedEventIds.append(eventId)
                        }
                    } catch {
                        print("更新事件失敗：\(error)")
                    }
                } else {
                    // 创建新事件
                    // 保存到本地缓存
                    EventCacheManager.shared.addEventToCache(event, for: userManager.userOpenId)
                    
                    // 保存到 Firebase
                    do {
                        try await EventManager.shared.addEvent(event: event)
                        // 收集保存后的事件ID
                        if let eventId = event.id {
                            savedEventIds.append(eventId)
                        }
                    } catch {
                        print("保存事件失敗：\(error)")
                    }
                }
            }
            
            // 如果原始事件数量多于当前事件数量，删除多余的事件
            if originalIds.count > formState.multiDayItems.count {
                for i in formState.multiDayItems.count..<originalIds.count {
                    let eventIdToDelete = originalIds[i]
                    // 软删除
                    EventManager.shared.softDeleteEvent(eventId: eventIdToDelete)
                }
            }
            
            // 等待一小段时间确保 Firebase 写入完成
            _ = try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
            
            // 从 Firebase 重新加载，更新本地缓存
            _ = try? await EventManager.shared.fetchEvents()
            
            // 通知 CalendarView 刷新
            NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
            
            await MainActor.run {
                // 传递保存后的事件ID列表
                onSaveToCalendar?(savedEventIds)
                dismiss()
            }
        }
    }
    
    private func saveToTemplate() {
        // 驗證：模版標題必填
        guard !templateTitle.isEmpty else {
            errorMessage = "請輸入模版標題"
            showErrorAlert = true
            return
        }
        
        // 将 MultiDayEventItem 转换回 PlanResult
        var dayPlans: [DayPlan] = []
        let calendar = Calendar.current
        
        // 按日期分组
        let groupedByDate = Dictionary(grouping: formState.multiDayItems) { item in
            calendar.startOfDay(for: item.date)
        }
        
        for (date, items) in groupedByDate.sorted(by: { $0.key < $1.key }) {
            // 获取该天的原始 blocks（包括 transit, buffer, flex, rest）
            let originalBlocks = originalBlocksByDay[date] ?? []
            
            // 创建编辑后的 activity blocks
            var editedActivityBlocks: [TimeBlock] = []
            for item in items.sorted(by: { $0.startTime < $1.startTime }) {
                let block = TimeBlock(
                    type: .activity,
                    startTime: item.startTime,
                    endTime: item.isHasEnd ? item.endTime : item.startTime,
                    title: item.title.isEmpty ? firstDayTitle : item.title,
                    location: item.destination,
                    isAnchor: false,
                    priority: 5,
                    description: item.information
                )
                editedActivityBlocks.append(block)
            }
            
            // 合并编辑后的 activity blocks 和原始的非 activity blocks（transit, buffer, flex, rest）
            // 按时间顺序合并所有 blocks
            var allBlocks: [TimeBlock] = []
            
            // 添加所有非 activity 类型的原始 blocks
            for originalBlock in originalBlocks {
                if originalBlock.type != .activity {
                    allBlocks.append(originalBlock)
                }
            }
            
            // 添加编辑后的 activity blocks
            allBlocks.append(contentsOf: editedActivityBlocks)
            
            // 按开始时间排序
            allBlocks.sort { $0.startTime < $1.startTime }
            
            dayPlans.append(DayPlan(date: date, blocks: allBlocks))
        }
        
        let updatedPlan = PlanResult(days: dayPlans, assumptions: plan.assumptions, riskFlags: plan.riskFlags)
        
        // 通过回调传回编辑后的 PlanResult 和模版標題，让调用方决定如何处理
        onSaveToTemplate?(updatedPlan, templateTitle)
        
        dismiss()
    }
    
    // MARK: - 辅助方法
    
    // 缓存 DateFormatter 以提高性能
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()
    
    private func dateToString(_ date: Date, format: String) -> String {
        let formatter = Self.dateFormatter
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
