//
//  PlanDetailView.swift
//  Secalender
//
//  行程详情页面（统一处理单日和多日）
//

import SwiftUI
import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

struct PlanDetailView: View {
    let plan: PlanResult
    var customTitle: String? = nil  // 用户自定义标题
    var onEdit: ((PlanResult) -> Void)? = nil           // 僅用於「編輯整個行程」按鈕，切換到 PlanEditView
    var onPlanUpdated: ((PlanResult) -> Void)? = nil      // block 編輯或 GPS 更新時同步 plan，不切換視圖
    var onAddToCalendar: (() -> Void)? = nil
    var onSaveToTemplate: ((String?) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil  // 关闭时的回调
    var onSave: (() -> Void)? = nil  // 储存回调
    var onShare: (() -> Void)? = nil  // 分享回调
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: FirebaseUserManager
    
    // 横向滚动相关状态
    @State private var selectedDayIndex: Int = 0  // 当前选中的日期索引
    @State private var planDays: [DayPlan] = []  // 可编辑的行程天数
    @State private var selectedBlock: TimeBlock? = nil  // 选中的 block（用于编辑）
    @State private var showBlockEditView = false  // 是否显示编辑页面
    
    // 功能菜单相关状态
    @State private var showActionSheet = false  // 显示操作菜单
    @State private var showShareSheet = false  // 显示分享菜单
    @State private var shareItems: [Any] = []  // 分享内容
    
    // GPS实时确认相关状态
    @StateObject private var locationManager = TransitLocationManager()
    @State private var gpsUpdateTask: Task<Void, Never>? = nil  // 后台GPS更新任务
    @State private var isDismissing = false  // 關閉中，避免 onPlanUpdated 在關閉時觸發重複彈出
    
    var body: some View {
        ZStack {
            // 白色背景，去除灰边
            Color.white
                .ignoresSafeArea()
            
            // 修复：直接检查数据，不使用 isReady 状态，避免一直转圈
            // 如果 plan.days 为空，显示空状态；否则直接显示内容
            if plan.days.isEmpty {
                // 空状态视图
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("plan_detail.invalid_data".localized())
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    // 头部：标题卡片（参考图片）
                    headerCardView
                    
                    // 日期选择栏
                    if !planDays.isEmpty {
                        daySelectorBar
                    }
                    
                    // 行程内容：横向滚动
                    horizontalScrollContentView
                }
            }
        }
        .onAppear {
            planDays = plan.days
            // 启动后台GPS检查任务（每10分钟检查一次从餐厅到下一个景点的交通时间）
            startGPSUpdateTask()
        }
        .onDisappear {
            // 停止后台GPS检查任务
            stopGPSUpdateTask()
        }
        #if os(iOS)
        // 修复：使用 navigationBarBackButtonHidden 而不是 navigationBarHidden，避免 toolbar 不显示
        .navigationBarBackButtonHidden(true)
        #endif
        #if os(iOS)
        .navigationTitle("編輯行程")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // 先停止 GPS 任務，避免關閉時 onPlanUpdated 觸發重複彈出
                    stopGPSUpdateTask()
                    isDismissing = true
                    if let onDismiss = onDismiss {
                        // 由父層控制關閉（fullScreenCover item 綁定）
                        onDismiss()
                    } else {
                        // 無 onDismiss 時使用系統 dismiss（如 TemplateDetailView）
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showActionSheet = true
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
                }
            }
        }
        .sheet(isPresented: $showBlockEditView) {
            if let block = selectedBlock {
                BlockEditView(
                    block: block,
                    onSave: { updatedBlock in
                        // 更新 block（不关闭编辑页面，继续编辑）
                        updateBlock(updatedBlock)
                        // 不关闭编辑页面，让用户可以继续编辑
                        // showBlockEditView = false
                        // selectedBlock = nil
                    },
                    onCancel: {
                        showBlockEditView = false
                        selectedBlock = nil
                    },
                    plan: plan,  // 传递完整行程用于地理围栏
                    interestTags: []  // 可以从plan或其他地方获取兴趣标签
                )
                .environmentObject(userManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog("選擇操作", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("儲存") {
                savePlan()
            }
            
            Button("分享") {
                sharePlan()
            }
            
            Button("加入行程") {
                addPlanToCalendar()
            }
            
            if onEdit != nil {
                Button("編輯整個行程") {
                    openPlanEditView()
                }
            }
            
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
        #endif
    }
    
    
    // MARK: - 头部卡片视图（参考图片）
    
    private var headerCardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(planTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(dateRangeString)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.teal, Color.green.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - 日期范围字符串
    private var dateRangeString: String {
        guard let firstDay = plan.days.first,
              let lastDay = plan.days.last else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "zh_TW")
        
        let startDate = formatter.string(from: firstDay.date)
        let endDate = formatter.string(from: lastDay.date)
        
        return "\(startDate) - \(endDate)"
    }
    
    private var backgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemBackground)
        #else
        return Color.white
        #endif
    }
    
    private var groupedBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
    
    private var gray6BackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray6)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    // MARK: - 日期选择栏（仅显示 D1、D2、D3）
    private var daySelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<planDays.count, id: \.self) { index in
                    dayButton(dayIndex: index, isSelected: selectedDayIndex == index)
                }
                
                // 添加更多日期按钮（参考图片）
                Button(action: {
                    // TODO: 添加更多日期
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .strokeBorder(Color(.systemGray4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .background(Circle().fill(Color.white))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(Color.white)
    }
    
    // MARK: - 日期按钮（仅显示 D1、D2、D3）
    private func dayButton(dayIndex: Int, isSelected: Bool) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                selectedDayIndex = dayIndex
            }
        }) {
            Text("D\(dayIndex + 1)")
                .font(.system(size: isSelected ? 16 : 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: isSelected ? 50 : 44, height: isSelected ? 50 : 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)  // 减小放大倍数，避免切边
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 日期格式化器
    private var dayDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日（E）"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }
    
    // MARK: - 横向滚动内容
    private var horizontalScrollContentView: some View {
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {  // 缩小两天之间的距离
                        ForEach(0..<planDays.count, id: \.self) { index in
                            DayColumnView(
                                dayIndex: index + 1,
                                day: planDays[index],
                                onBlockTap: { block in
                                    // 点击 block 时，打开编辑页面
                                    selectedBlock = block
                                    showBlockEditView = true
                                }
                            )
                            .frame(width: geometry.size.width)
                            .id("day-\(index)")
                            .background(
                                GeometryReader { dayGeometry in
                                    Color.clear
                                        .preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: [ScrollOffsetData(
                                                index: index,
                                                offset: dayGeometry.frame(in: .named("scroll")).minX
                                            )]
                                        )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 0)  // 去除两侧 padding，避免灰边
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offsetData in
                    handleScrollOffsetChange(offsetData: offsetData, screenWidth: geometry.size.width)
                }
            }
            .background(Color.white)  // 确保背景是白色
            .onAppear {
                planDays = plan.days
            }
            .onChange(of: selectedDayIndex) { oldIndex, newIndex in
                // 当选中日期变化时，滚动到对应位置（仅在用户点击日期按钮时触发）
                if oldIndex != newIndex {
                    // 使用 DispatchQueue 确保在主线程执行，并延迟一点以确保视图已准备好
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("day-\(newIndex)", anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 处理滚动位置变化（参考 MultiEventView）
    private func handleScrollOffsetChange(offsetData: [ScrollOffsetData], screenWidth: CGFloat) {
        // 计算当前最接近屏幕中心的日期
        let centerX = screenWidth / 2
        
        var minDistance: CGFloat = .infinity
        var closestIndex = selectedDayIndex
        
        for data in offsetData {
            let dayWidth = screenWidth
            let dayCenter = data.offset + dayWidth / 2
            let distance = abs(dayCenter - centerX)
            
            if distance < minDistance {
                minDistance = distance
                closestIndex = data.index
            }
        }
        
        // 更新选中的日期索引（避免循环更新，只在用户滚动时更新）
        if closestIndex != selectedDayIndex && closestIndex >= 0 && closestIndex < planDays.count {
            selectedDayIndex = closestIndex
        }
    }
    
    
    // MARK: - 智能重新计算时间（根据修改的行程位置采用不同策略）
    private func recalculateTimesIntelligently(
        for blocks: [TimeBlock],
        dayDate: Date,
        updatedBlockId: UUID,
        isFirst: Bool,
        isLast: Bool
    ) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        var result: [TimeBlock] = []
        let visibleBlocks = blocks.filter { $0.type == .activity || $0.type == .flex || $0.type == .rest }
        
        // 找到更新的 block
        guard let updatedBlock = visibleBlocks.first(where: { $0.id == updatedBlockId }),
              let updatedIndex = visibleBlocks.firstIndex(where: { $0.id == updatedBlockId }) else {
            // 如果找不到，使用原来的方法
            return recalculateTimes(for: blocks, dayDate: dayDate)
        }
        
        if isFirst {
            // 第一个行程修改：调整出发时间，不影响后续行程时间
            return recalculateTimesForFirstActivity(
                blocks: visibleBlocks,
                updatedBlock: updatedBlock,
                updatedIndex: updatedIndex,
                dayDate: dayDate
            )
        } else if isLast {
            // 最后行程修改：修改前交通时间，并把弹性时间往后延
            return recalculateTimesForLastActivity(
                blocks: visibleBlocks,
                updatedBlock: updatedBlock,
                updatedIndex: updatedIndex,
                dayDate: dayDate
            )
        } else {
            // 中间行程修改：计算前后行程交通时间，缩短其行程持续时间
            return recalculateTimesForMiddleActivity(
                blocks: visibleBlocks,
                updatedBlock: updatedBlock,
                updatedIndex: updatedIndex,
                dayDate: dayDate
            )
        }
    }
    
    // MARK: - 重新计算时间（将 buffer 合并到 transit 中）
    private func recalculateTimes(for blocks: [TimeBlock], dayDate: Date) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        var result: [TimeBlock] = []
        
        // 先提取所有 activity、flex、rest 类型的 block（按原始顺序）
        let visibleBlocks = blocks.filter { $0.type == .activity || $0.type == .flex || $0.type == .rest }
        
        for (index, block) in visibleBlocks.enumerated() {
            if block.type == .activity {
                // 如果不是第一个 activity，添加 transit（包含 buffer 时间）
                if index > 0 {
                    // 计算 transit 时间（基础时间 + buffer 时间）
                    // 基础 transit 时间：30分钟
                    // buffer 时间：根据 transit 时间动态计算（transit 越长，buffer 越多）
                    let baseTransitDuration: TimeInterval = 30 * 60  // 30分钟基础交通时间
                    
                    // 计算 buffer 时间：基础 10分钟 + transit 时间的 20%（最多 20分钟）
                    let bufferRatio: TimeInterval = 0.2  // 20%
                    let maxBufferDuration: TimeInterval = 20 * 60  // 最多 20分钟
                    let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
                    let minBufferDuration: TimeInterval = 10 * 60  // 最少 10分钟
                    let bufferDuration = max(calculatedBuffer, minBufferDuration)
                    
                    // 总 transit 时间 = 基础 transit + buffer
                    let totalTransitDuration = baseTransitDuration + bufferDuration
                    let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
                    
                    if transitEnd <= dayEnd {
                        // 创建 transit block（包含 buffer 时间，但不显示 buffer）
                        result.append(TimeBlock(
                            id: UUID(),
                            type: .transit,
                            startTime: currentTime,
                            endTime: transitEnd,
                            title: "前往下一地点",
                            location: nil,
                            isAnchor: false,
                            priority: 5,
                            description: nil
                        ))
                        currentTime = transitEnd
                    }
                }
                
                // 添加 activity（保持原有时长）
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                // 对于 flex 和 rest，保持原有时长
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        return result
    }
    
    // MARK: - 计算属性
    
    private var planTitle: String {
        // 优先使用用户自定义标题（"此行的主题"）
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }
        // 如果没有自定义标题，尝试从模板标题中提取
        // 否则使用默认标题
        let destination = extractDestination()
        return "\(destination)\(plan.days.count)日深度遊"
    }
    
    private var planDestination: String {
        let destination = extractDestination()
        if let country = extractCountry(from: destination) {
            return "\(country),\(destination)"
        }
        return destination
    }
    
    private func extractDestination() -> String {
        // 修复：扫描前 N 个 activity，找第一个有 location 的，提高成功率
        for day in plan.days {
            // 扫描该天的所有 activity blocks
            for block in day.blocks where block.type == .activity {
                if let location = block.location, !location.isEmpty {
                    // 尝试提取城市名（假设格式为 "城市" 或 "国家 - 城市"）
                    if location.contains(" - ") {
                        return String(location.split(separator: " - ").last ?? "")
                    }
                    return location
                }
            }
        }
        return "未知目的地"
    }
    
    private func extractCountry(from destination: String) -> String? {
        // 简单的国家映射
        let countryMap: [String: String] = [
            "東京": "日本",
            "京都": "日本",
            "大阪": "日本",
            "首爾": "韓國",
            "台北": "台灣",
            "曼谷": "泰國"
        ]
        
        for (city, country) in countryMap {
            if destination.contains(city) {
                return country
            }
        }
        return nil
    }
    
    // MARK: - 更新 Block
    private func updateBlock(_ updatedBlock: TimeBlock) {
        // 找到并更新对应的 block
        for dayIndex in 0..<planDays.count {
            if let blockIndex = planDays[dayIndex].blocks.firstIndex(where: { $0.id == updatedBlock.id }) {
                // 获取当前天的所有 activity blocks（用于判断位置）
                let activityBlocks = planDays[dayIndex].blocks.filter { $0.type == .activity }
                let activityIndex = activityBlocks.firstIndex(where: { $0.id == updatedBlock.id })
                
                // 判断是第一个、中间还是最后一个行程
                let isFirstActivity = activityIndex == 0
                let isLastActivity = activityIndex == activityBlocks.count - 1
                
                // 更新 block 信息
                planDays[dayIndex].blocks[blockIndex] = updatedBlock
                
                // 智能重新计算时间（根据位置采用不同策略）
                let visibleBlocks = planDays[dayIndex].blocks.filter { 
                    $0.type == .activity || $0.type == .flex || $0.type == .rest 
                }
                
                // 使用智能重算方法
                let recalculatedBlocks = recalculateTimesIntelligently(
                    for: visibleBlocks,
                    dayDate: planDays[dayIndex].date,
                    updatedBlockId: updatedBlock.id,
                    isFirst: isFirstActivity,
                    isLast: isLastActivity
                )
                planDays[dayIndex].blocks = recalculatedBlocks
                
                // 同步 plan 給父層（關閉中不觸發，避免重複彈出）
                if !isDismissing {
                    var updatedPlan = plan
                    updatedPlan.days = planDays
                    onPlanUpdated?(updatedPlan)
                }
                
                break
            }
        }
    }
    
    // MARK: - 開啟整個行程編輯
    /// 用戶明確點擊「編輯整個行程」時，將目前編輯後的 plan 傳給父層並進入 PlanEditView
    private func openPlanEditView() {
        var updatedPlan = plan
        updatedPlan.days = planDays
        onEdit?(updatedPlan)
    }
    
    // MARK: - 储存行程
    private func savePlan() {
        let userId = userManager.userOpenId
        
        // 生成默认标题
        let templateTitle: String
        if let customTitle = customTitle, !customTitle.isEmpty {
            templateTitle = customTitle
        } else {
            let destination = extractDestination()
            if destination != "未知目的地" {
                templateTitle = "\(destination) \(planDays.count)天行程"
            } else {
                templateTitle = "行程模板 \(planDays.count)天"
            }
        }
        
        // 提取目的地
        let destination = extractDestination()
        
        // 创建模板
        var updatedPlan = plan
        updatedPlan.days = planDays
        let template = SavedTripTemplate(
            title: templateTitle,
            plan: updatedPlan,
            savedDate: Date(),
            tags: [],
            destination: destination != "未知目的地" ? destination : nil
        )
        
        // 保存模板
        TripTemplateManager.shared.saveTemplate(template, for: userId, syncToAppleCalendar: false)
        
        // 显示成功提示
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            let alert = UIAlertController(title: "成功", message: "已保存到行程模板：\(templateTitle)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            rootViewController.present(alert, animated: true)
        }
        #endif
        
        onSave?()
    }
    
    // MARK: - 分享行程
    private func sharePlan() {
        // 构建分享文本
        var shareText = "\(planTitle)\n\n"
        
        let destination = extractDestination()
        if destination != "未知目的地" {
            shareText += "目的地：\(destination)\n"
        }
        
        shareText += "行程天数：\(planDays.count)天\n\n"
        
        // 添加每天的行程
        for (dayIndex, day) in planDays.enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "M月d日"
            dateFormatter.locale = Locale(identifier: "zh_TW")
            shareText += "第\(dayIndex + 1)天（\(dateFormatter.string(from: day.date))）：\n"
            
            let activities = day.blocks.filter { $0.type == .activity }
            for activity in activities {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.locale = Locale(identifier: "zh_TW")
                let timeString = timeFormatter.string(from: activity.startTime)
                shareText += "\(timeString) - \(activity.title)"
                if let location = activity.location {
                    shareText += " (\(location))"
                }
                shareText += "\n"
            }
            
            if dayIndex < planDays.count - 1 {
                shareText += "\n"
            }
        }
        
        shareItems = [shareText]
        showShareSheet = true
    }
    
    // MARK: - 加入行程（添加到日历）
    private func addPlanToCalendar() {
        var updatedPlan = plan
        updatedPlan.days = planDays
        
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            
            let items = PlanGenerator.shared.convertToScheduleItems(updatedPlan)
            
            for item in items {
                let startDate = combine(date: item.date, time: item.startTime)
                let endDate = combine(date: item.date, time: item.endTime)
                
                let dateString = dateFormatter.string(from: item.date)
                let startString = timeFormatter.string(from: startDate)
                let endString = timeFormatter.string(from: endDate)
                
                var event = Event()
                event.title = item.title
                event.creatorOpenid = userManager.userOpenId
                event.color = "#4285F4"
                event.date = dateString
                event.startTime = startString
                event.endTime = endString
                event.endDate = dateString
                event.destination = item.location
                event.mapObj = ""
                event.openChecked = 0
                event.personChecked = 0
                event.createTime = ""
                event.information = item.description
                event.groupId = nil
                
                do {
                    try await EventManager.shared.addEvent(event: event)
                } catch {
                    print("添加事件失敗：\(error)")
                }
            }
            
            await MainActor.run {
                #if os(iOS)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    let alert = UIAlertController(title: "成功", message: "已將行程加入行事曆", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "確定", style: .default))
                    rootViewController.present(alert, animated: true)
                }
                #endif
                onAddToCalendar?()
            }
        }
    }
    
    // MARK: - 辅助函数
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: calendar.component(.second, from: time),
            of: date
        ) ?? date
    }
    
    // MARK: - 第一个行程修改：调整出发时间，不影响后续行程时间
    private func recalculateTimesForFirstActivity(
        blocks: [TimeBlock],
        updatedBlock: TimeBlock,
        updatedIndex: Int,
        dayDate: Date
    ) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        var result: [TimeBlock] = []
        var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        // 第一个行程：使用更新后的时间，但保持原有时长
        let activityDuration = updatedBlock.endTime.timeIntervalSince(updatedBlock.startTime)
        let activityEnd = currentTime.addingTimeInterval(activityDuration)
        
        if activityEnd <= dayEnd {
            var firstBlock = updatedBlock
            firstBlock.startTime = currentTime
            firstBlock.endTime = activityEnd
            result.append(firstBlock)
            currentTime = activityEnd
        }
        
        // 后续行程：保持原有顺序和时间间隔
        for index in 1..<blocks.count {
            let block = blocks[index]
            
            if block.type == .activity {
                // 添加 transit 时间
                let baseTransitDuration: TimeInterval = 30 * 60
                let bufferRatio: TimeInterval = 0.2
                let maxBufferDuration: TimeInterval = 20 * 60
                let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
                let minBufferDuration: TimeInterval = 10 * 60
                let bufferDuration = max(calculatedBuffer, minBufferDuration)
                let totalTransitDuration = baseTransitDuration + bufferDuration
                let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
                
                if transitEnd <= dayEnd {
                    result.append(TimeBlock(
                        id: UUID(),
                        type: .transit,
                        startTime: currentTime,
                        endTime: transitEnd,
                        title: "前往下一地点",
                        location: nil,
                        isAnchor: false,
                        priority: 5,
                        description: nil
                    ))
                    currentTime = transitEnd
                }
                
                // 添加 activity（保持原有时长）
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                // 对于 flex 和 rest，保持原有时长
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        return result
    }
    
    // MARK: - 最后行程修改：修改前交通时间，并把弹性时间往后延
    private func recalculateTimesForLastActivity(
        blocks: [TimeBlock],
        updatedBlock: TimeBlock,
        updatedIndex: Int,
        dayDate: Date
    ) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        var result: [TimeBlock] = []
        var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        // 处理前面的行程（保持原有顺序）
        for index in 0..<updatedIndex {
            let block = blocks[index]
            
            if block.type == .activity {
                // 如果不是第一个 activity，添加 transit
                if index > 0 {
                    let baseTransitDuration: TimeInterval = 30 * 60
                    let bufferRatio: TimeInterval = 0.2
                    let maxBufferDuration: TimeInterval = 20 * 60
                    let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
                    let minBufferDuration: TimeInterval = 10 * 60
                    let bufferDuration = max(calculatedBuffer, minBufferDuration)
                    let totalTransitDuration = baseTransitDuration + bufferDuration
                    let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
                    
                    if transitEnd <= dayEnd {
                        result.append(TimeBlock(
                            id: UUID(),
                            type: .transit,
                            startTime: currentTime,
                            endTime: transitEnd,
                            title: "前往下一地点",
                            location: nil,
                            isAnchor: false,
                            priority: 5,
                            description: nil
                        ))
                        currentTime = transitEnd
                    }
                }
                
                // 添加 activity
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        // 添加最后一个行程前的 transit（重新计算）
        if updatedIndex > 0 {
            let previousBlock = blocks[updatedIndex - 1]
            let baseTransitDuration: TimeInterval = 30 * 60
            let bufferRatio: TimeInterval = 0.2
            let maxBufferDuration: TimeInterval = 20 * 60
            let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
            let minBufferDuration: TimeInterval = 10 * 60
            let bufferDuration = max(calculatedBuffer, minBufferDuration)
            let totalTransitDuration = baseTransitDuration + bufferDuration
            let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
            
            if transitEnd <= dayEnd {
                result.append(TimeBlock(
                    id: UUID(),
                    type: .transit,
                    startTime: currentTime,
                    endTime: transitEnd,
                    title: "前往下一地点",
                    location: nil,
                    isAnchor: false,
                    priority: 5,
                    description: nil
                ))
                currentTime = transitEnd
            }
        }
        
        // 添加最后一个行程（使用更新后的时间，但保持原有时长）
        let activityDuration = updatedBlock.endTime.timeIntervalSince(updatedBlock.startTime)
        let activityEnd = currentTime.addingTimeInterval(activityDuration)
        
        if activityEnd <= dayEnd {
            var lastBlock = updatedBlock
            lastBlock.startTime = currentTime
            lastBlock.endTime = activityEnd
            result.append(lastBlock)
            currentTime = activityEnd
        }
        
        // 如果有弹性时间，将其往后延
        if updatedIndex < blocks.count - 1 {
            let remainingBlocks = blocks[(updatedIndex + 1)...]
            for block in remainingBlocks {
                if block.type == .flex || block.type == .rest {
                    let duration = block.endTime.timeIntervalSince(block.startTime)
                    let blockEnd = currentTime.addingTimeInterval(duration)
                    
                    if blockEnd <= dayEnd {
                        var updatedBlock = block
                        updatedBlock.startTime = currentTime
                        updatedBlock.endTime = blockEnd
                        result.append(updatedBlock)
                        currentTime = blockEnd
                    }
                }
            }
        }
        
        return result
    }
    
    // MARK: - 中间行程修改：计算前后行程交通时间，缩短其行程持续时间
    private func recalculateTimesForMiddleActivity(
        blocks: [TimeBlock],
        updatedBlock: TimeBlock,
        updatedIndex: Int,
        dayDate: Date
    ) -> [TimeBlock] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)
        let dayEnd = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        var result: [TimeBlock] = []
        var currentTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayStart) ?? dayStart
        
        // 处理前面的行程（保持原有顺序）
        for index in 0..<updatedIndex {
            let block = blocks[index]
            
            if block.type == .activity {
                if index > 0 {
                    let baseTransitDuration: TimeInterval = 30 * 60
                    let bufferRatio: TimeInterval = 0.2
                    let maxBufferDuration: TimeInterval = 20 * 60
                    let calculatedBuffer = min(baseTransitDuration * bufferRatio, maxBufferDuration)
                    let minBufferDuration: TimeInterval = 10 * 60
                    let bufferDuration = max(calculatedBuffer, minBufferDuration)
                    let totalTransitDuration = baseTransitDuration + bufferDuration
                    let transitEnd = currentTime.addingTimeInterval(totalTransitDuration)
                    
                    if transitEnd <= dayEnd {
                        result.append(TimeBlock(
                            id: UUID(),
                            type: .transit,
                            startTime: currentTime,
                            endTime: transitEnd,
                            title: "前往下一地点",
                            location: nil,
                            isAnchor: false,
                            priority: 5,
                            description: nil
                        ))
                        currentTime = transitEnd
                    }
                }
                
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        // 添加前一个行程到当前行程的 transit（重新计算）
        if updatedIndex > 0 {
            let previousBlock = blocks[updatedIndex - 1]
            // 尝试使用实际交通时间计算
            var transitDuration: TimeInterval = 30 * 60 + 10 * 60  // 默认值
            
            // 如果两个行程都有地点，尝试计算实际交通时间
            if let fromLocation = previousBlock.location,
               let toLocation = updatedBlock.location,
               !fromLocation.isEmpty,
               !toLocation.isEmpty {
                // 使用同步方法获取默认值，实际计算在后台进行
                if let calculatedTime = calculateTransitTime(from: previousBlock, to: updatedBlock) {
                    transitDuration = calculatedTime
                }
            }
            
            let transitEnd = currentTime.addingTimeInterval(transitDuration)
            
            if transitEnd <= dayEnd {
                result.append(TimeBlock(
                    id: UUID(),
                    type: .transit,
                    startTime: currentTime,
                    endTime: transitEnd,
                    title: "前往下一地点",
                    location: nil,
                    isAnchor: false,
                    priority: 5,
                    description: nil
                ))
                currentTime = transitEnd
            }
        }
        
        // 添加当前修改的行程（缩短持续时间以适应时间限制）
        let originalDuration = updatedBlock.endTime.timeIntervalSince(updatedBlock.startTime)
        let maxAvailableTime = dayEnd.timeIntervalSince(currentTime)
        let activityDuration = min(originalDuration, maxAvailableTime * 0.8)  // 保留20%缓冲
        let activityEnd = currentTime.addingTimeInterval(activityDuration)
        
        if activityEnd <= dayEnd {
            var middleBlock = updatedBlock
            middleBlock.startTime = currentTime
            middleBlock.endTime = activityEnd
            result.append(middleBlock)
            currentTime = activityEnd
        }
        
        // 添加当前行程到下一个行程的 transit（重新计算）
        if updatedIndex < blocks.count - 1 {
            let nextBlock = blocks[updatedIndex + 1]
            if nextBlock.type == .activity {
                var transitDuration: TimeInterval = 30 * 60 + 10 * 60  // 默认值
                
                if let fromLocation = updatedBlock.location,
                   let toLocation = nextBlock.location,
                   !fromLocation.isEmpty,
                   !toLocation.isEmpty {
                    if let calculatedTime = calculateTransitTime(from: updatedBlock, to: nextBlock) {
                        transitDuration = calculatedTime
                    }
                }
                
                let transitEnd = currentTime.addingTimeInterval(transitDuration)
                
                if transitEnd <= dayEnd {
                    result.append(TimeBlock(
                        id: UUID(),
                        type: .transit,
                        startTime: currentTime,
                        endTime: transitEnd,
                        title: "前往下一地点",
                        location: nil,
                        isAnchor: false,
                        priority: 5,
                        description: nil
                    ))
                    currentTime = transitEnd
                }
            }
        }
        
        // 处理后续行程（保持原有顺序）
        for index in (updatedIndex + 1)..<blocks.count {
            let block = blocks[index]
            
            if block.type == .activity {
                let activityDuration = block.endTime.timeIntervalSince(block.startTime)
                let activityEnd = currentTime.addingTimeInterval(activityDuration)
                
                if activityEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = activityEnd
                    result.append(updatedBlock)
                    currentTime = activityEnd
                }
            } else if block.type == .flex || block.type == .rest {
                let duration = block.endTime.timeIntervalSince(block.startTime)
                let blockEnd = currentTime.addingTimeInterval(duration)
                
                if blockEnd <= dayEnd {
                    var updatedBlock = block
                    updatedBlock.startTime = currentTime
                    updatedBlock.endTime = blockEnd
                    result.append(updatedBlock)
                    currentTime = blockEnd
                }
            }
        }
        
        return result
    }
    
    // MARK: - 计算两个行程之间的交通时间
    /// 计算两个行程之间的交通时间（同步版本，返回默认值或实际计算值）
    /// 注意：由于地理编码和路线计算是异步的，这里先返回默认值，实际计算在后台进行
    private func calculateTransitTime(from: TimeBlock, to: TimeBlock) -> TimeInterval? {
        // 如果两个行程都有地点，尝试计算实际交通时间
        guard let fromLocation = from.location,
              let toLocation = to.location,
              !fromLocation.isEmpty,
              !toLocation.isEmpty else {
            return nil
        }
        
        // 使用地理编码将地址转换为坐标，然后计算交通时间
        // 由于这是同步方法，我们使用默认值，实际计算在后台异步进行
        // 这里返回 nil，让调用者使用默认时间
        // TODO: 可以改为异步方法，使用 DispatchGroup 或 async/await
        
        // 临时方案：使用默认交通时间（30分钟基础 + 10分钟缓冲）
        let defaultTransitDuration: TimeInterval = 30 * 60
        let defaultBufferDuration: TimeInterval = 10 * 60
        return defaultTransitDuration + defaultBufferDuration
    }
    
    // MARK: - 异步计算交通时间（用于实际计算）
    /// 异步计算两个行程之间的实际交通时间
    private func calculateTransitTimeAsync(
        from: TimeBlock,
        to: TimeBlock,
        completion: @escaping (TimeInterval?) -> Void
    ) {
        guard let fromLocation = from.location,
              let toLocation = to.location,
              !fromLocation.isEmpty,
              !toLocation.isEmpty else {
            completion(nil)
            return
        }
        
        // 使用地理编码将地址转换为坐标
        let geocoder = CLGeocoder()
        
        // 先编码起始地址
        geocoder.geocodeAddressString(fromLocation) { fromPlacemarks, fromError in
            guard let fromPlacemark = fromPlacemarks?.first,
                  let fromCoordinate = fromPlacemark.location else {
                // 如果编码失败，使用默认时间
                let defaultTime: TimeInterval = 30 * 60 + 10 * 60
                completion(defaultTime)
                return
            }
            
            // 再编码目标地址
            geocoder.geocodeAddressString(toLocation) { toPlacemarks, toError in
                guard let toPlacemark = toPlacemarks?.first,
                      let toCoordinate = toPlacemark.location else {
                    // 如果编码失败，使用默认时间
                    let defaultTime: TimeInterval = 30 * 60 + 10 * 60
                    completion(defaultTime)
                    return
                }
                
                // 使用 TravelTimeCalculator 计算实际交通时间
                TravelTimeCalculator.shared.calculateTravelTime(
                    from: fromCoordinate,
                    to: toCoordinate
                ) { efficientTime, taxiTime, routeInfo in
                    // 使用最有效率的时间（步行或公共交通）
                    // 如果计算失败，使用默认时间
                    if let travelTime = efficientTime {
                        completion(travelTime)
                    } else {
                        // 如果计算失败，使用默认时间
                        let defaultTime: TimeInterval = 30 * 60 + 10 * 60
                        completion(defaultTime)
                    }
                }
            }
        }
    }
    
    // MARK: - GPS实时确认功能
    
    /// 启动后台GPS更新任务（每10分钟检查一次从餐厅到下一个景点的交通时间）
    private func startGPSUpdateTask() {
        // 取消之前的任务
        stopGPSUpdateTask()
        
        // 请求位置权限
        locationManager.requestPermission()
        
        // 创建后台任务
        gpsUpdateTask = Task {
            while !Task.isCancelled {
                // 每10分钟检查一次
                try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000) // 10分钟
                
                // 检查是否有需要实时确认的交通块（从餐厅到下一个景点）
                await updateTransitTimesFromRestaurants()
            }
        }
    }
    
    /// 停止后台GPS更新任务
    private func stopGPSUpdateTask() {
        gpsUpdateTask?.cancel()
        gpsUpdateTask = nil
    }
    
    /// 更新从餐厅到下一个景点的交通时间
    @MainActor
    private func updateTransitTimesFromRestaurants() async {
        guard !isDismissing else { return }
        guard let currentLocation = locationManager.currentLocation else {
            print("📍 [PlanDetailView] GPS位置不可用，跳过交通时间更新")
            return
        }
        
        var hasUpdates = false
        
        // 遍历所有天的行程
        for dayIndex in 0..<planDays.count {
            var updatedBlocks = planDays[dayIndex].blocks
            
            // 查找所有"从餐厅前往下一地点"的交通块
            for blockIndex in 0..<updatedBlocks.count {
                let block = updatedBlocks[blockIndex]
                
                // 檢查可依 GPS 更新交通時間的塊：從餐廳、前往住宿、從住宿出發等
                let isUpdatableTransit = block.title.contains("从餐厅") ||
                    block.title.contains("從餐廳") ||
                    block.title.contains("前往住宿") ||
                    block.title.contains("從住宿")
                if block.type == .transit,
                   isUpdatableTransit,
                   let destinationLocation = block.location,
                   !destinationLocation.isEmpty {
                    
                    // 使用地理编码获取目标地点的坐标
                    let geocoder = CLGeocoder()
                    
                    do {
                        let placemarks = try await geocoder.geocodeAddressString(destinationLocation)
                        
                        if let placemark = placemarks.first,
                           let destinationCoordinate = placemark.location {
                            
                            // 计算实际交通时间
                            await withCheckedContinuation { continuation in
                                TravelTimeCalculator.shared.calculateTravelTime(
                                    from: currentLocation,
                                    to: destinationCoordinate
                                ) { efficientTime, taxiTime, routeInfo in
                                    // 使用最有效率的时间（步行或公共交通）
                                    if let travelTime = efficientTime {
                                        // 添加10分钟缓冲时间
                                        let totalTime = travelTime + (10 * 60)
                                        
                                        // 更新交通块的时间
                                        let newEndTime = block.startTime.addingTimeInterval(totalTime)
                                        
                                        var updatedBlock = block
                                        updatedBlock.endTime = newEndTime
                                        
                                        // 更新描述，显示实时计算的时间
                                        let minutes = Int(totalTime / 60)
                                        updatedBlock.description = "从餐厅前往下一地点（实时GPS确认：约\(minutes)分钟）\n\(routeInfo ?? "")"
                                        
                                        updatedBlocks[blockIndex] = updatedBlock
                                        hasUpdates = true
                                        
                                        print("📍 [PlanDetailView] 更新交通时间：从餐厅到\(destinationLocation)，预计\(minutes)分钟")
                                    }
                                    
                                    continuation.resume()
                                }
                            }
                        }
                    } catch {
                        print("📍 [PlanDetailView] 地理编码失败：\(error.localizedDescription)")
                    }
                }
            }
            
            // 如果有更新，保存到 planDays
            if hasUpdates {
                planDays[dayIndex].blocks = updatedBlocks
                
                // 同步 plan 給父層（關閉中不觸發，避免重複彈出）
                if !isDismissing {
                    var updatedPlan = plan
                    updatedPlan.days = planDays
                    onPlanUpdated?(updatedPlan)
                }
            }
        }
    }
}

// MARK: - 单日列视图（横向滚动）

struct DayColumnView: View {
    let dayIndex: Int
    let day: DayPlan
    let onBlockTap: ((TimeBlock) -> Void)?  // 添加 onBlockTap 参数
    
    private var dayBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemBackground)
        #else
        return Color.white
        #endif
    }
    
    private var dayDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日（E）"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dayHeaderView
                blocksListView
            }
            .padding(.bottom, 40)
        }
        .background(Color.white)
    }
    
    // MARK: - 日期标题视图
    private var dayHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayDateFormatter.string(from: day.date))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                

            }
            
            Spacer()
            
            // AI 建議路線按钮（参考图片）
            Button(action: {
                // TODO: 实现 AI 建议路线功能
            }) {
                Text("AI 建議路線")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
     // MARK: - 行程卡片列表视图
     private var blocksListView: some View {
         ForEach(Array(day.blocks.enumerated()), id: \.element.id) { index, block in
             // 显示 activity、transit、flex、rest，隐藏 buffer
             if block.type == .activity || block.type == .flex || block.type == .rest || block.type == .transit {
                 blockCardView(for: block, at: index)
             }
         }
     }
    
    // MARK: - 单个行程卡片视图
    private func blockCardView(for block: TimeBlock, at index: Int) -> some View {
        // 获取下一个活动的地点（用于导航）
        // 地图应用会使用GPS自动定位当前位置，所以不需要前一个地点
        var nextLocation: String? = nil
        
        // 查找后一个 activity
        for i in (index + 1)..<day.blocks.count {
            if day.blocks[i].type == .activity, let loc = day.blocks[i].location, !loc.isEmpty {
                nextLocation = loc
                break
            }
        }
        
        return BlockCardView(
            block: block,
            blockIndex: index,
            nextLocation: nextLocation,
            onTap: {
                onBlockTap?(block)
            }
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Block 卡片视图

struct BlockCardView: View {
    let block: TimeBlock
    let blockIndex: Int  // 当前 block 的索引
    var nextLocation: String? = nil  // 下一个活动的地点（用于交通导航，地图会使用GPS定位当前位置）
    var onTap: (() -> Void)? = nil  // 点击回调（可选）
    
    private var itemGray6BackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray6)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标圆圈
            ZStack {
                Circle()
                    .fill(iconColorForBlock(block))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconForBlock(block))
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            
            // 中间：标题和时间信息
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                // 时间和类型标签
                HStack(spacing: 4) {
                    // 如果是餐饮类型，显示时间范围（开始时间 - 结束时间）
                    if isRestaurantType(block) {
                        Text("\(formattedTime(from: block.startTime)) - \(formattedTime(from: block.endTime))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(iconColorForBlock(block))
                    } else {
                        // 其他类型只显示开始时间
                        Text(formattedTime(from: block.startTime))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(iconColorForBlock(block))
                    }
                    
                    Text("·")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    
                    Text(typeLabelForBlock(block))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 编辑按钮（仅 activity 类型显示）
            if block.type == .activity {
                Button(action: {
                    onTap?()
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
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())  // 让整个卡片可点击
        .onTapGesture {
            // 餐饮类型：跳转到地图应用搜索附近餐厅
            if isRestaurantType(block) {
                openMapForRestaurant()
            }
            // 交通类型：跳转到导航应用
            else if block.type == .transit {
                openMapForNavigation()
            }
            // 其他类型：保持原有行为（点击编辑按钮）
        }
    }
    
    // MARK: - 地图跳转功能
    
    /// 打开地图应用搜索附近餐厅
    private func openMapForRestaurant() {
        #if os(iOS)
        // 获取当前地点（如果有）或使用通用搜索
        let searchQuery: String
        if let location = block.location, !location.isEmpty {
            // 如果有地点，搜索该地点附近的餐厅
            searchQuery = "\(location) 附近餐厅"
        } else {
            // 如果没有地点，使用通用搜索
            searchQuery = "附近餐厅"
        }
        
        // 优先使用 Google Maps（如果可用），否则使用 Apple Maps
        let availableApps = MapAppManager.shared.getAvailableMapApps()
        
        if let googleMaps = availableApps.first(where: { $0 == .google }) {
            MapAppManager.shared.openMapApp(googleMaps, destination: searchQuery)
        } else if let appleMaps = availableApps.first(where: { $0 == .apple }) {
            MapAppManager.shared.openMapApp(appleMaps, destination: searchQuery)
        } else {
            // 如果都没有，使用 Apple Maps 作为默认
            MapAppManager.shared.openMapApp(.apple, destination: searchQuery)
        }
        #endif
    }
    
    /// 打开导航应用导航到下一个地点
    private func openMapForNavigation() {
        #if os(iOS)
        // 交通类型：导航到下一个地点
        guard let destination = nextLocation, !destination.isEmpty else {
            // 如果没有下一个地点，无法导航
            return
        }
        
        // 优先使用 Google Maps（如果可用），否则使用 Apple Maps
        let availableApps = MapAppManager.shared.getAvailableMapApps()
        
        if let googleMaps = availableApps.first(where: { $0 == .google }) {
            MapAppManager.shared.openMapApp(googleMaps, destination: destination)
        } else if let appleMaps = availableApps.first(where: { $0 == .apple }) {
            MapAppManager.shared.openMapApp(appleMaps, destination: destination)
        } else {
            // 如果都没有，使用 Apple Maps 作为默认
            MapAppManager.shared.openMapApp(.apple, destination: destination)
        }
        #endif
    }
    
    // 根据 block 类型返回不同的颜色
    private func iconColorForBlock(_ block: TimeBlock) -> Color {
        switch block.type {
        case .activity:
            // 如果是餐饮类型，使用橙色
            let title = block.title.lowercased()
            if title.contains("餐廳") || title.contains("餐厅") || 
               title.contains("restaurant") || title.contains("美食") ||
               title.contains("午餐") || title.contains("晚餐") ||
               title.contains("早餐") || title.contains("拉麵") {
                return .orange
            }
            return .blue
        case .transit:
            return .orange
        case .buffer:
            return .gray
        case .flex:
            return .purple
        case .rest:
            return .green
        }
    }
    
    // 根据 block 类型返回标签文本
    private func typeLabelForBlock(_ block: TimeBlock) -> String {
        switch block.type {
        case .activity:
            // 如果是餐饮类型，显示"餐饮"
            let title = block.title.lowercased()
            if title.contains("餐廳") || title.contains("餐厅") || 
               title.contains("restaurant") || title.contains("美食") ||
               title.contains("午餐") || title.contains("晚餐") ||
               title.contains("早餐") || title.contains("拉麵") {
                return "餐饮"
            }
            return ""
        case .transit:
            return "交通"
        case .buffer:
            return "缓冲"
        case .flex:
            return "弹性"
        case .rest:
            return "休息"
        }
    }
    
    // 修复：基于 TimeBlockType 而不是 title 匹配，避免语言问题
    private func iconForBlock(_ block: TimeBlock) -> String {
        switch block.type {
        case .activity:
            // 对于 activity，可以根据 location 或 title 进一步细分
            let title = block.title.lowercased()
            if title.contains("餐廳") || title.contains("餐厅") || 
               title.contains("restaurant") || title.contains("美食") || 
               title.contains("拉麵") || title.contains("午餐") || 
               title.contains("晚餐") || title.contains("早餐") {
                return "fork.knife"
            } else if title.contains("寺") || title.contains("神宮") || title.contains("神社") || title.contains("廟") {
                return "building.columns.fill"
            } else if title.contains("觀景") || title.contains("展望") || title.contains("塔") {
                return "binoculars.fill"
            } else {
                return "mappin.circle.fill"
            }
        case .transit:
            return "bus.fill"
        case .buffer:
            return "clock.fill"
        case .flex:
            return "clock.arrow.circlepath"
        case .rest:
            return "bed.double.fill"
        }
    }
    
    // 修复：使用单一方案（DateFormatter）并缓存，避免性能浪费和格式不一致
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }()
    
    private func formattedTime(from date: Date) -> String {
        // 使用缓存的 formatter，统一使用 24 小时制
        return Self.timeFormatter.string(from: date)
    }
    
    // 判断是否为餐饮类型
    private func isRestaurantType(_ block: TimeBlock) -> Bool {
        guard block.type == .activity else { return false }
        let title = block.title.lowercased()
        return title.contains("餐廳") || title.contains("餐厅") || 
               title.contains("restaurant") || title.contains("美食") ||
               title.contains("午餐") || title.contains("晚餐") ||
               title.contains("早餐") || title.contains("拉麵")
    }
}

// MARK: - 交通位置管理器（用于实时GPS确认）

class TransitLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 50  // 50米更新一次，节省电量
    }
    
    func requestPermission() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 [TransitLocationManager] GPS定位失败：\(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}


