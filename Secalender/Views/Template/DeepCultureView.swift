//
//  DeepCultureView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//  深度文化功能：基于GPS位置搜索历史艺术周边特色，选择后直接创建1日行程
//

import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 深度文化步骤枚举
enum DeepCultureStep: Int {
    case step1 = 1  // 周边特色选择
    case step2 = 2  // AI生成
}

struct DeepCultureView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    // 步骤控制
    @State private var currentStep: DeepCultureStep = .step1
    
    // GPS定位
    @StateObject private var locationManager = LocationPickerManager()
    @State private var currentGPSLocation: CLLocation? = nil
    @State private var gpsLocationAddress: String = ""
    @State private var gpsLocationName: String = ""
    @State private var isLocatingGPS = false
    @State private var hasAutoRequestedGPS = false
    
    // 周边特色
    @State private var surroundingAttractions: [SurroundingAttraction] = []
    @State private var selectedSurroundingAttractions: Set<String> = []
    @State private var isLoadingSurroundingFeatures = false
    
    // AI生成
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0.0
    @State private var currentTask: String = ""
    @State private var completedTasks: [String] = []
    @State private var pendingTasks: [String] = []
    
    // 生成结果
    @State private var generatedPlan: PlanResult? = nil
    @State private var showPlanDetailView = false
    @State private var showPlanEditView = false
    @State private var planToEdit: PlanResult? = nil
    
    // 多行程检视相关状态
    @State private var showMultiEventView = false
    @State private var savedEventIds: [Int] = []
    @State private var allEvents: [Event] = []  // 用于 MultiEventView 的事件列表
    
    // 错误处理
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 进度指示器
                    progressIndicator
                    
                    // 内容区域
                    ScrollView {
                        VStack(spacing: 24) {
                            switch currentStep {
                            case .step1:
                                step1View
                            case .step2:
                                step2View
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    
                    // 底部按钮
                    bottomButtons
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep != .step1 {
                        Button(action: {
                            goToPreviousStep()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                    } else {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                
                // 系統自帶主題：不顯示右上角選單
            }
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("好") {}
            } message: {
                Text(errorMessage)
            }
            .fullScreenCover(item: $generatedPlan) { plan in
                NavigationView {
                    PlanDetailView(
                        plan: plan,
                        customTitle: "深度文化行程",
                        onEdit: { planToEdit in
                            self.planToEdit = planToEdit
                            generatedPlan = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showPlanEditView = true
                            }
                        },
                        onPlanUpdated: { updatedPlan in
                            self.planToEdit = updatedPlan
                            generatedPlan = updatedPlan
                        },
                        onAddToCalendar: nil,
                        onSaveToTemplate: nil,
                        onDismiss: {
                            generatedPlan = nil
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .sheet(isPresented: $showPlanEditView) {
                if let plan = planToEdit ?? generatedPlan {
                    PlanEditView(
                        plan: plan,
                        customTitle: "深度文化行程",
                        onSaveToCalendar: { eventIds in
                            // 保存到日历后，导航到多行程检视页面
                            savedEventIds = eventIds
                            showPlanEditView = false
                            // 加载事件列表
                            Task {
                                await loadEventsForMultiView()
                                await MainActor.run {
                                    showMultiEventView = true
                                }
                            }
                        },
                        onSaveToTemplate: { editedPlan, title in
                            savePlanToTemplate(editedPlan, title: title ?? "深度文化行程")
                            planToEdit = nil
                            generatedPlan = editedPlan
                            showPlanEditView = false
                        },
                        onDismiss: {
                            showPlanEditView = false
                            if let editedPlan = planToEdit {
                                generatedPlan = editedPlan
                            }
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .sheet(isPresented: $showMultiEventView) {
                NavigationView {
                    MultiEventView(
                        eventIds: savedEventIds,
                        allEvents: $allEvents,
                        source: .template,  // 标识从行程模版打开
                        onComplete: {
                            // 完成操作后不关闭页面，保持在多行程检视页面
                        },
                        onRefreshEvents: {
                            // 刷新事件列表
                            await loadEventsForMultiView()
                        },
                        onDismiss: nil,  // 从模版打开时不使用 onDismiss
                        onBackToTemplate: {
                            // 返回到行程模版（PlanDetailView）
                            showMultiEventView = false
                            // 重新打开详情页
                            if let plan = generatedPlan {
                                generatedPlan = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    generatedPlan = plan
                                }
                            }
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .onAppear {
                // 自动获取GPS位置
                if !hasAutoRequestedGPS {
                    hasAutoRequestedGPS = true
                    requestGPSLocation()
                }
            }
        }
    }
    
    // MARK: - 加载事件列表（用于 MultiEventView）
    private func loadEventsForMultiView() async {
        guard !userManager.userOpenId.isEmpty else { return }
        
        // 从本地缓存加载事件
        let cachedEvents = EventCacheManager.shared.loadEvents(for: userManager.userOpenId)
        await MainActor.run {
            allEvents = cachedEvents.filter { $0.deleted != 1 }
        }
        
        // 后台同步 Firebase
        Task {
            do {
                try await EventManager.shared.fetchEvents()
                let updatedEvents = EventCacheManager.shared.loadEvents(for: userManager.userOpenId)
                await MainActor.run {
                    allEvents = updatedEvents.filter { $0.deleted != 1 }
                }
            } catch {
                print("⚠️ 加载事件失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 进度指示器
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Text(stepDisplayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progressPercentage))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progressPercentage / 100, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private var progressPercentage: Double {
        switch currentStep {
        case .step1: return 50.0
        case .step2: return 100.0
        }
    }
    
    private var stepDisplayText: String {
        switch currentStep {
        case .step1: return "步驟 1/2"
        case .step2: return "步驟 2/2"
        }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case .step1: return "深度文化"
        case .step2: return "智能規劃"
        }
    }
    
    // MARK: - 步骤1：周边特色选择
    private var step1View: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题和副标题
            VStack(alignment: .leading, spacing: 8) {
                Text("deep_culture.select_features".localized())
                    .font(.system(size: 28, weight: .bold))
                
                Text("deep_culture.features_description".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // GPS定位状态（仅显示加载状态，不显示地址）
            if isLocatingGPS {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("deep_culture.locating".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            
            // 周边特色选择
            VStack(alignment: .leading, spacing: 16) {
                Text("deep_culture.historical_features".localized())
                    .font(.headline)
                
                if isLoadingSurroundingFeatures {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("deep_culture.searching_features".localized())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                } else if surroundingAttractions.isEmpty {
                    Text("deep_culture.no_features".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        let currentSelectionCount = selectedSurroundingAttractions.count
                        let maxSelection = 3
                        let minSelection = 1
                        if currentSelectionCount > 0 {
                            Text("deep_culture.selected_attractions".localized(with: currentSelectionCount, maxSelection))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("deep_culture.selection_range".localized(with: minSelection, maxSelection))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(surroundingAttractions) { attraction in
                                let isSelected = selectedSurroundingAttractions.contains(attraction.id)
                                let isDisabled = !isSelected && currentSelectionCount >= maxSelection
                                
                                SurroundingAttractionButton(
                                    attraction: attraction,
                                    isSelected: isSelected,
                                    isDisabled: isDisabled
                                ) {
                                    if isSelected {
                                        selectedSurroundingAttractions.remove(attraction.id)
                                    } else if currentSelectionCount < maxSelection {
                                        selectedSurroundingAttractions.insert(attraction.id)
                                    }
                                }
                            }
                            
                            // 添加"其他"选项
                            let isOtherSelected = selectedSurroundingAttractions.contains("other")
                            let isOtherDisabled = !isOtherSelected && currentSelectionCount >= maxSelection
                            
                            SurroundingAttractionButton(
                                attraction: SurroundingAttraction(
                                    id: "other",
                                    name: "deep_culture.other_option".localized(),
                                    category: "deep_culture.other_category".localized(),
                                    icon: "ellipsis.circle"
                                ),
                                isSelected: isOtherSelected,
                                isDisabled: isOtherDisabled
                            ) {
                                if isOtherSelected {
                                    selectedSurroundingAttractions.remove("other")
                                } else if currentSelectionCount < maxSelection {
                                    selectedSurroundingAttractions.insert("other")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 步骤2：AI生成
    private var step2View: some View {
        VStack(spacing: 32) {
            // 中央图标
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            // 标题和副标题
            VStack(spacing: 8) {
                Text("deep_culture.ai_creating".localized())
                    .font(.system(size: 20, weight: .semibold))
                
                Text("deep_culture.takes_time".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 任务列表
            VStack(alignment: .leading, spacing: 16) {
                ForEach(completedTasks, id: \.self) { task in
                    TaskRow(task: task, status: .completed)
                }
                
                if !currentTask.isEmpty {
                    TaskRow(task: currentTask, status: .inProgress)
                }
                
                ForEach(pendingTasks, id: \.self) { task in
                    TaskRow(task: task, status: .pending)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            
            // 进度条
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("deep_culture.completing".localized())
                        .font(.subheadline)
                    Spacer()
                    Text("\(completedTasks.count + (currentTask.isEmpty ? 0 : 1))/\(pendingTasks.count + completedTasks.count + (currentTask.isEmpty ? 0 : 1))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(UIColor.systemGray5))
                            .frame(height: 6)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * generationProgress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }
    
    // MARK: - 底部按钮
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            if currentStep == .step1 {
                Button(action: {
                    startGeneration()
                }) {
                    Text("deep_culture.start_planning".localized())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceedToStep2 ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!canProceedToStep2)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var canProceedToStep2: Bool {
        currentGPSLocation != nil && selectedSurroundingAttractions.count >= 1 && selectedSurroundingAttractions.count <= 3
    }
    
    // MARK: - 导航方法
    private func goToPreviousStep() {
        withAnimation {
            currentStep = .step1
            isGenerating = false
        }
    }
    
    // MARK: - GPS定位
    @MainActor
    private func requestGPSLocation() {
        isLocatingGPS = true
        gpsLocationAddress = ""
        gpsLocationName = ""
        
        // 先尝试从缓存加载
        if let cachedCoordinate = LocationCacheManager.shared.loadLastLocation() {
            let cachedLocation = CLLocation(latitude: cachedCoordinate.latitude, longitude: cachedCoordinate.longitude)
            currentGPSLocation = cachedLocation
            reverseGeocodeLocation(cachedLocation)
            isLocatingGPS = false
            return
        }
        
        // 请求位置权限
        locationManager.requestPermission()
        
        // 异步获取位置
        Task {
            // 等待位置更新（最多等待5秒）
            let startTime = Date()
            while locationManager.currentLocation == nil && Date().timeIntervalSince(startTime) < 5.0 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            }
            
            if let location = locationManager.currentLocation {
                currentGPSLocation = location
                LocationCacheManager.shared.saveLastLocation(location)
                reverseGeocodeLocation(location)
            } else {
                // 尝试一次性定位
                if let location = await locationManager.requestLocationOnce() {
                    currentGPSLocation = location
                    LocationCacheManager.shared.saveLastLocation(location)
                    reverseGeocodeLocation(location)
                } else {
                    isLocatingGPS = false
                    gpsLocationAddress = "定位失败，请检查位置权限设置"
                }
            }
        }
    }
    
    private func reverseGeocodeLocation(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                self.isLocatingGPS = false
                if let placemark = placemarks?.first {
                    // 保存位置名字
                    self.gpsLocationName = placemark.name ?? ""
                    
                    // 构建地址（不包含名字和国家，因为名字单独显示）
                    var addressComponents: [String] = []
                    if let locality = placemark.locality { addressComponents.append(locality) }
                    // 行政区域（省/州）- 台湾不显示
                    let isTaiwan = placemark.country == "Taiwan" || placemark.country == "台灣" || placemark.country == "台湾"
                    if !isTaiwan, let administrativeArea = placemark.administrativeArea { 
                        addressComponents.append(administrativeArea) 
                    }
                    // 不包含国家信息
                    self.gpsLocationAddress = addressComponents.joined(separator: ", ")
                    
                    // 定位成功后，自动加载历史艺术周边特色
                    if !self.gpsLocationAddress.isEmpty {
                        self.loadHistoricalArtAttractions()
                    }
                } else {
                    self.gpsLocationName = ""
                    self.gpsLocationAddress = "位置: \(location.coordinate.latitude), \(location.coordinate.longitude)"
                }
            }
        }
    }
    
    // MARK: - 加载历史艺术周边特色（基于GPS位置）
    private func loadHistoricalArtAttractions() {
        guard currentGPSLocation != nil else { return }
        
        // 如果已有数据，不重新加载
        if !surroundingAttractions.isEmpty {
            return
        }
        
        isLoadingSurroundingFeatures = true
        
        Task {
            do {
                let attractions = try await withTimeout(seconds: 20) {
                    try await self.fetchHistoricalArtAttractions()
                }
                
                await MainActor.run {
                    // 确保返回6个特色
                    self.surroundingAttractions = Array(attractions.prefix(6))
                    if self.surroundingAttractions.count < 6 {
                        // 如果少于6个，用默认值补充
                        let defaultAttractions = self.getDefaultHistoricalAttractions()
                        let needed = 6 - self.surroundingAttractions.count
                        self.surroundingAttractions.append(contentsOf: defaultAttractions.prefix(needed))
                    }
                    self.isLoadingSurroundingFeatures = false
                }
            } catch {
                print("❌ [DeepCultureView] 获取历史艺术特色失败: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingSurroundingFeatures = false
                    // 使用默认特色
                    self.surroundingAttractions = Array(self.getDefaultHistoricalAttractions().prefix(6))
                }
            }
        }
    }
    
    private func fetchHistoricalArtAttractions() async throws -> [SurroundingAttraction] {
        // 使用位置地址或名字作为搜索基础
        let locationName = gpsLocationName.isEmpty ? gpsLocationAddress : gpsLocationName
        
        let prompt = locationName.isEmpty 
            ? "推荐当前位置附近的历史、艺术、文化相关的6个知名景点，包括博物馆、历史建筑、艺术馆、文化遗址等，只返回JSON数组：[\"景点1\",\"景点2\",...]"
            : "推荐\(locationName)附近的历史、艺术、文化相关的6个知名景点，包括博物馆、历史建筑、艺术馆、文化遗址等，只返回JSON数组：[\"景点1\",\"景点2\",...]"
        
        let response = try await OpenAIManager.shared.generateSurroundingAttractions(
            prompt: prompt,
            timeout: 30.0
        )
        
        return parseSurroundingAttractions(response)
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "操作超时"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func parseSurroundingAttractions(_ jsonString: String) -> [SurroundingAttraction] {
        if let jsonData = jsonString.data(using: .utf8),
           let nameArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
            return parseAttractionsFromNameArray(nameArray)
        }
        
        // 如果JSON解析失败，尝试提取数组内容
        if let startRange = jsonString.range(of: "["),
           let endRange = jsonString.range(of: "]", range: startRange.upperBound..<jsonString.endIndex) {
            let arrayContent = String(jsonString[startRange.upperBound..<endRange.lowerBound])
            let names = arrayContent.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r\t")) }
                .filter { !$0.isEmpty }
            return parseAttractionsFromNameArray(names)
        }
        
        return []
    }
    
    private func parseAttractionsFromNameArray(_ nameArray: [String]) -> [SurroundingAttraction] {
        var attractions: [SurroundingAttraction] = []
        
        for (index, name) in nameArray.enumerated() {
            guard !name.isEmpty else { continue }
            
            let (category, icon) = inferCategoryAndIcon(from: name)
            
            let attraction = SurroundingAttraction(
                id: "\(index)",
                name: name,
                category: category,
                icon: icon
            )
            attractions.append(attraction)
        }
        
        return attractions
    }
    
    private func inferCategoryAndIcon(from name: String) -> (String, String) {
        let lowercased = name.lowercased()
        
        // 历史相关
        if lowercased.contains("历史") || lowercased.contains("史") || lowercased.contains("古") || lowercased.contains("遗址") || lowercased.contains("遗迹") {
            return ("历史", "building.columns")
        }
        // 艺术相关
        if lowercased.contains("艺术") || lowercased.contains("美術") || lowercased.contains("画廊") || lowercased.contains("画") {
            return ("艺术", "paintpalette")
        }
        // 博物馆
        if lowercased.contains("博物馆") || lowercased.contains("博物院") || lowercased.contains("museum") {
            return ("博物馆", "building.2")
        }
        // 文化
        if lowercased.contains("文化") || lowercased.contains("文化中心") {
            return ("文化", "book.closed")
        }
        // 建筑
        if lowercased.contains("建筑") || lowercased.contains("宮") || lowercased.contains("殿") || lowercased.contains("寺") || lowercased.contains("庙") {
            return ("建筑", "building")
        }
        
        // 默认
        return ("文化", "building.columns")
    }
    
    private func getDefaultHistoricalAttractions() -> [SurroundingAttraction] {
        return [
            SurroundingAttraction(id: "default_1", name: "历史博物馆", category: "博物馆", icon: "building.2"),
            SurroundingAttraction(id: "default_2", name: "艺术馆", category: "艺术", icon: "paintpalette"),
            SurroundingAttraction(id: "default_3", name: "文化遗址", category: "历史", icon: "building.columns"),
            SurroundingAttraction(id: "default_4", name: "历史建筑", category: "建筑", icon: "building"),
            SurroundingAttraction(id: "default_5", name: "文化中心", category: "文化", icon: "book.closed"),
            SurroundingAttraction(id: "default_6", name: "艺术空间", category: "艺术", icon: "paintpalette"),
        ]
    }
    
    // MARK: - AI生成
    private func startGeneration() {
        guard currentGPSLocation != nil, !selectedSurroundingAttractions.isEmpty else {
            errorMessage = "缺少必要信息"
            showErrorAlert = true
            return
        }
        
        currentStep = .step2
        isGenerating = true
        generationProgress = 0.0
        completedTasks = []
        currentTask = ""
        
        pendingTasks = [
            "正在分析目的地資訊",
            "正在規劃活動安排",
            "正在優化路線",
            "正在生成完整行程"
        ]
        
        Task {
            await generatePlan()
        }
    }
    
    private func generatePlan() async {
        guard let location = currentGPSLocation else {
            await MainActor.run {
                errorMessage = "缺少位置信息"
                showErrorAlert = true
                isGenerating = false
            }
            return
        }
        
        // 检查是否选择了"其他"选项
        let hasOtherOption = selectedSurroundingAttractions.contains("other")
        
        // 获取选中的周边特色名称（排除"其他"选项）
        let selectedAttractionNames = surroundingAttractions
            .filter { selectedSurroundingAttractions.contains($0.id) && $0.id != "other" }
            .map { $0.name }
        
        // 使用GPS位置地址作为目的地
        let destination = gpsLocationAddress.isEmpty ? (gpsLocationName.isEmpty ? "当前位置" : gpsLocationName) : gpsLocationAddress
        
        // 固定为一日游
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = startDate
        
        var slots = ExtractedSlots()
        slots.destination = SlotInfo(value: destination, confidence: 1.0)
        slots.dateRange = SlotInfo(value: DateRange(startDate: startDate, endDate: endDate), confidence: 1.0)
        slots.interestTags = []  // 深度文化不需要兴趣偏好
        slots.budgetLevel = SlotInfo(value: .moderate, confidence: 1.0)
        slots.pace = SlotInfo(value: .moderate, confidence: 1.0)
        slots.transportPreference = SlotInfo(value: .publicTransport, confidence: 1.0)  // 默认大众运输
        
        let classificationResult = ClassificationResult(
            inputType: .typeA,
            slots: slots,
            assumptions: [],
            riskFlags: []
        )
        
        let apiTask = Task {
            let plan = try await generateAIPoweredPlan(from: classificationResult, selectedAttractions: selectedAttractionNames, hasOtherOption: hasOtherOption)
            await MainActor.run {
                generatedPlan = plan
            }
        }
        
        // 任务列表动画
        await MainActor.run {
            currentTask = pendingTasks.removeFirst()
            generationProgress = 0.25
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.5
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.75
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
        }
        
        do {
            _ = try await apiTask.value
            
            await MainActor.run {
                if !currentTask.isEmpty {
                    completedTasks.append(currentTask)
                    currentTask = ""
                }
                generationProgress = 1.0
                
                if let plan = generatedPlan {
                    Task { @MainActor in
                        await convertAndSavePlan(plan)
                    }
                }
            }
        } catch {
            await MainActor.run {
                if !currentTask.isEmpty {
                    currentTask = ""
                }
                errorMessage = "生成行程失败：\(error.localizedDescription)"
                showErrorAlert = true
                isGenerating = false
            }
        }
    }
    
    private func generateAIPoweredPlan(from result: ClassificationResult, selectedAttractions: [String], hasOtherOption: Bool = false) async throws -> PlanResult {
        guard let destination = result.slots.destination.value else {
            throw PlanGenerationError.missingDestination
        }
        
        guard let dateRange = result.slots.dateRange.value else {
            throw PlanGenerationError.missingDateInfo
        }
        
        // 固定为1天
        let numberOfDays = 1
        
        let aiPlan = try await AITripGenerator.shared.generateAIItinerary(
            destination: destination,
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
            durationDays: numberOfDays,
            interestTags: [],
            pace: .moderate,
            walkingLevel: nil,
            transportPreference: .publicTransport,
            selectedAttractions: selectedAttractions,
            currentGPSLocation: currentGPSLocation,
            accommodationAddress: nil,
            accommodationType: nil,
            hasOtherOption: hasOtherOption,
            themeKey: "deep_culture"
        )
        
        var plan = try AITripGenerator.shared.convertToPlanResult(aiPlan, slots: result.slots)
        plan.assumptions = result.assumptions
        
        return plan
    }
    
    @MainActor
    private func convertAndSavePlan(_ plan: PlanResult) async {
        isGenerating = false
        ActivityRecorder.recordAIUsed()
        savePlanToTemplate(plan, title: "深度文化行程")
        generatedPlan = plan
        
        if !plan.days.isEmpty {
            showPlanDetailView = true
        } else {
            errorMessage = "生成的行程数据无效"
            showErrorAlert = true
        }
    }
    
    private func savePlanToTemplate(_ plan: PlanResult, title: String) {
        // 保存行程模板的逻辑
        // TODO: 实现保存逻辑
    }
    
    // MARK: - 任务行组件
    struct TaskRow: View {
        let task: String
        let status: TaskStatus
        
        enum TaskStatus {
            case completed
            case inProgress
            case pending
        }
        
        var body: some View {
            HStack(spacing: 12) {
                switch status {
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .inProgress:
                    ProgressView()
                        .scaleEffect(0.8)
                case .pending:
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                }
                
                Text(task)
                    .font(.subheadline)
                    .foregroundColor(status == .pending ? .secondary : .primary)
            }
        }
    }
    
    // MARK: - 周边特色按钮组件
    struct SurroundingAttractionButton: View {
        let attraction: SurroundingAttraction
        let isSelected: Bool
        let isDisabled: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: attraction.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isSelected ? .white : (isDisabled ? .gray : .blue))
                    
                    Text(attraction.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .white : (isDisabled ? .gray : .primary))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(attraction.category)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : (isDisabled ? .gray.opacity(0.6) : .secondary))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(isSelected ? Color.blue : (isDisabled ? Color(.systemGray5) : Color(.systemBackground)))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
                .opacity(isDisabled ? 0.6 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDisabled)
        }
    }
}
