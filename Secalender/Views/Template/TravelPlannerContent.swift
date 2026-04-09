//
//  TravelPlannerContent.swift
//  Secalender
//
//  旅遊行程主題專用：完整四步驟行程規劃 UI，與 AIPlannerView 旅遊流程一致。
//  供 TravelPlanningView 使用；AIPlannerView 日後可改為時間管理總入口。
//

import SwiftUI
import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

// 共用類型（PlanningStep, TransportationType, SurroundingAttraction, InterestTag, SpecialRestriction, BudgetLevel 擴展）定義於 AIPlannerView.swift，本檔案僅實作旅遊行程 UI。

/// 旅遊行程專用內容視圖：僅四步驟（目的地→偏好→細節→生成），無主題表單。
struct TravelPlannerContent: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    // 步骤控制
    @State private var currentStep: PlanningStep = .step1
    
    // 键盘焦点控制
    @FocusState private var isTextFieldFocused: Bool
    
    // 步骤1：基本信息
    @State private var tripTheme: String = ""
    @State private var destination: String = ""
    @State private var selectedDestination: String? = nil  // 快速选择
    @State private var selectedCountry: String? = nil
    @State private var selectedCity: String? = nil
    @State private var showLocationPicker = false
    
    // 旅行天数
    @State private var travelDays: Int = 3
    
    // 同行人数
    @State private var adults: Int = 1
    @State private var children: Int = 0
    
    // 步骤2：偏好设置
    @State private var selectedInterests: Set<InterestTag> = []
    @State private var selectedTransportation: TransportationType? = .publicTransport
    @State private var selectedPace: Pace = .relaxed  // 預設輕鬆，僅支援輕鬆/緊湊
    @State private var budgetLevel: BudgetLevel = .moderate
    // 修改内容：旅游主题模块（与 AITripGenerator 内建列表一致）
    @State private var selectedTravelThemeModuleId: String? = nil
    
    // 步骤3：行程細節優化
    @State private var surroundingAttractions: [SurroundingAttraction] = []
    @State private var selectedSurroundingAttractions: Set<String> = []  // 存储选中的ID
    @State private var customSurroundingTags: [String] = []  // 用戶自訂標籤
    @State private var customTagInput: String = ""  // 自訂標籤輸入框
    /// 每個自訂標籤必須填寫期望行程內容（與標籤對應）
    @State private var customTagItineraryNotes: [String: String] = [:]
    @State private var isLoadingSurroundingFeatures = false
    @State private var selectedRestrictions: Set<SpecialRestriction> = []
    @State private var additionalRequirements: String = ""
    @State private var lastLoadedDestination: String = ""  // 跟踪上次加载的目的地
    
    // GPS定位位置
    @StateObject private var locationManager = LocationPickerManager()
    @State private var currentGPSLocation: CLLocation? = nil
    @State private var gpsLocationAddress: String = ""
    @State private var gpsLocationName: String = ""  // 定位位置的名字
    @State private var isLocatingGPS = false
    @State private var userCountryName: String? = nil  // 用户所在国家（中文）
    
    // 自定义出发位置
    @State private var useCustomDepartureLocation = false
    @State private var customDepartureAddress: String = ""
    @State private var customDepartureCoordinate: CLLocationCoordinate2D? = nil
    @State private var showDepartureLocationPicker = false
    @State private var hasAutoRequestedGPS = false  // 标记是否已自动请求过GPS
    
    /// 出發日期／時間（行程第一天）
    @State private var departureTripStartDate: Date = Date()
    @State private var departureTripStartTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var departurePickerEndDate: Date? = nil
    @State private var departurePickerEndTime: Date? = nil
    @State private var departurePickerIsAllDay = false
    @State private var departurePickerIsHasEnd = false
    
    // 住宿选择（简化为统一地址搜索）
    @State private var accommodationAddress: String = ""
    @State private var accommodationCoordinate: CLLocationCoordinate2D? = nil
    @State private var showAccommodationPicker = false
    
    // 步骤4：AI生成
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0.0
    @State private var currentTask: String = ""
    @State private var completedTasks: [String] = []
    @State private var pendingTasks: [String] = []
    
    // 生成結果（引擎唯一輸出為 GenerationResult；plan 僅過渡兼容）
    @State private var generatedResult: GenerationResult? = nil
    @State private var showPlanDetailView = false
    @State private var showPlanEditView = false
    @State private var planToEdit: PlanResult? = nil  // 用于编辑的 plan
    
    // 多行程检视相关状态
    @State private var showMultiEventView = false
    @State private var savedEventIds: [Int] = []
    @State private var allEvents: [Event] = []  // 用于 MultiEventView 的事件列表
    
    // 错误处理
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // 目的地历史记录（使用 @AppStorage 持久化）
    @AppStorage("destinationHistory") private var destinationHistoryData: Data = Data()
    
    // AI 生成付費開關（預設關閉，開啟後需單獨付費）
    @State private var enableAIGeneration: Bool = false
    
    // 计算属性：从历史记录中获取快速目的地选项（只显示城市名，最多4个）
    private var quickDestinations: [String] {
        guard let history = try? JSONDecoder().decode([String].self, from: destinationHistoryData) else {
            // 如果没有历史记录，返回默认值
            return ["東京", "京都", "大阪"]
        }
        // 提取城市名（如果格式是"国家 - 城市"，只取城市部分）
        // 只显示最后4个（最新的在前面，所以取前4个）
        let cityNames = history.prefix(4).map { dest -> String in
            if dest.contains(" - ") {
                // 提取城市名（"国家 - 城市" 格式）
                let components = dest.components(separatedBy: " - ")
                return components.last ?? dest
            }
            return dest
        }
        return Array(cityNames)
    }
    
    // 修改内容：與 AITripGenerator.inferTravelThemeModuleId 單一數據源對齊（避免 UI 與生成器推断不一致）
    private func inferDefaultTravelThemeId() -> String {
        AITripGenerator.inferTravelThemeModuleId(
            children: children,
            combinedUserText: "\(tripTheme) \(additionalRequirements)",
            interestTagRawValues: selectedInterests.map { $0.rawValue }
        )
    }
    
    private var resolvedTravelThemeId: String {
        selectedTravelThemeModuleId ?? inferDefaultTravelThemeId()
    }
    
    private var resolvedTravelThemeModule: TravelThemeModule? {
        AITripGenerator.builtInTravelThemeModules.first { $0.id == resolvedTravelThemeId }
    }
    
    private func travelIntensityDisplay(_ level: PlanningIntensityLevel) -> String {
        switch level {
        case .relaxed: return "节奏偏轻松"
        case .standard: return "节奏标准"
        case .intensive: return "节奏较紧凑"
        }
    }
    
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
                            case .step3:
                                step3View
                            case .step4:
                                step4View
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)  // 滑动时收起键盘
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            // 点击空白区域时收起键盘
                            isTextFieldFocused = false
                            hideKeyboard()
                        }
                    )
                    
                    // 底部按钮
                    bottomButtons
                }
            }
            .navigationTitle(
                currentStep == .step1 ? "行程基礎" :
                currentStep == .step2 ? "進階設定" :
                currentStep == .step3 ? "行程細節" : "智能規劃"
            )
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
                
            }
            .task {
                // 从缓存加载用户所在国家（如果已有）
                if let cachedCountry = LocationCacheManager.shared.loadUserCountry() {
                    userCountryName = cachedCountry
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                NavigationView {
                    CountryCityPickerView(
                        selectedCountry: $selectedCountry,
                        selectedCity: $selectedCity,
                        userCountry: userCountryName,
                        onSelect: { country, city in
                            selectedCountry = country
                            selectedCity = city
                            let newDestination = "\(country) - \(city)"
                            destination = newDestination
                            saveDestinationToHistory(newDestination)
                            showLocationPicker = false
                            // 如果目的地改变，清空周边特色
                            if newDestination != lastLoadedDestination {
                                clearSurroundingFeatures()
                            }
                        }
                    )
                    .navigationTitle("選擇地點")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showAccommodationPicker) {
                NavigationView {
                    LocationPickerView(
                        selectedAddress: $accommodationAddress,
                        selectedCoordinate: $accommodationCoordinate
                    )
                    .navigationTitle("選擇住宿地址")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showDepartureLocationPicker) {
                NavigationView {
                    LocationPickerView(
                        selectedAddress: $customDepartureAddress,
                        selectedCoordinate: $customDepartureCoordinate
                    )
                    .navigationTitle("選擇出發地址")
                    .navigationBarTitleDisplayMode(.inline)
                    .onDisappear {
                        if !customDepartureAddress.isEmpty {
                            // 自定义地址已设置
                        }
                    }
                }
            }
            .onChange(of: destination) { oldValue, newValue in
                // 当目的地改变时，如果与上次加载的不同，清空周边特色
                if !newValue.isEmpty && newValue != lastLoadedDestination && !surroundingAttractions.isEmpty {
                    clearSurroundingFeatures()
                }
            }
            // 生成引擎輸出為 GenerationResult；PlanDetailView 以 result.plan 顯示，並提供套用/建議/scheduler
            .fullScreenCover(item: $generatedResult) { result in
                NavigationView {
                    PlanDetailView(
                        plan: result.plan ?? PlanResult(days: [], assumptions: result.assumptions, riskFlags: result.riskFlags),
                        customTitle: tripTheme.isEmpty ? nil : tripTheme,
                        generationResult: result,
                        onEdit: { planToEdit in
                            self.planToEdit = planToEdit
                            generatedResult = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showPlanEditView = true
                            }
                        },
                        onPlanUpdated: { updatedPlan in
                            self.planToEdit = updatedPlan
                            if var r = generatedResult { r.plan = updatedPlan; generatedResult = r }
                        },
                        onAddToCalendar: nil,
                        onSaveToTemplate: nil,
                        onDismiss: {
                            generatedResult = nil
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .sheet(isPresented: $showPlanEditView) {
                if let plan = planToEdit ?? generatedResult?.plan {
                    PlanEditView(
                        plan: plan,
                        customTitle: tripTheme.isEmpty ? nil : tripTheme,  // 传递用户填写的"此行的主題"
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
                            savePlanToTemplate(editedPlan, title: title)
                            if var r = generatedResult { r.plan = editedPlan; generatedResult = r }
                            showPlanEditView = false
                        },
                        onDismiss: {
                            showPlanEditView = false
                            if let editedPlan = planToEdit, var r = generatedResult {
                                r.plan = editedPlan
                                generatedResult = r
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
                            showMultiEventView = false
                            if let r = generatedResult {
                                generatedResult = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    generatedResult = r
                                }
                            }
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            // 修复：删除 onChange dismiss 逻辑，避免多重 dismiss
            // PlanDetailView 关闭时只关闭自己的 sheet，AIPlannerView 只在流程完成时 dismiss
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("好") {}
            } message: {
                Text(errorMessage)
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
                _ = try await EventManager.shared.fetchEvents()
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
        case .step1: return 25.0
        case .step2: return 50.0
        case .step3: return 75.0
        case .step4: return 100.0
        }
    }
    
    private var stepDisplayText: String {
        switch currentStep {
        case .step1: return "步驟 1/4"
        case .step2: return "步驟 2/4"
        case .step3: return "步驟 3/4"
        case .step4: return "步驟 4/4"
        }
    }
    
    // MARK: - 步骤1：基本信息
    private var step1View: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("旅遊行程")
                    .font(.system(size: 28, weight: .bold))
                Text("開始規劃您的旅程")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
    
            // 主题输入
            VStack(alignment: .leading, spacing: 8) {
                Text("ai_planner.trip_theme".localized())
                    .font(.headline)
                
                TextField("ai_planner.trip_theme_placeholder".localized(), text: $tripTheme)
                    .focused($isTextFieldFocused)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                    )
                    .onSubmit {
                        // 按回车时收起键盘
                        isTextFieldFocused = false
                    }
            }
            
            // 目的地输入（国家-城市选择器）
            VStack(alignment: .leading, spacing: 8) {
                Text("ai_planner.where_are_you_going".localized())
                    .font(.headline)
                
                Button(action: {
                    showLocationPicker = true
                }) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                        Text(destination.isEmpty ? "ai_planner.search_destination".localized() : destination)
                            .foregroundColor(destination.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                    )
                }
                
                // 快速选择按钮（只显示城市名）
                if !quickDestinations.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(quickDestinations, id: \.self) { cityName in
                            Button(action: {
                                // 收起键盘
                                isTextFieldFocused = false
                                hideKeyboard()
                                // 从历史记录中找到完整的目的地字符串
                                let fullDestination = findFullDestination(for: cityName)
                                let newDestination = fullDestination ?? cityName
                                // 如果目的地改变，清空周边特色
                                if newDestination != destination && newDestination != lastLoadedDestination {
                                    clearSurroundingFeatures()
                                }
                                destination = newDestination
                                selectedDestination = cityName
                                selectedCountry = nil
                                selectedCity = nil
                                saveDestinationToHistory(destination)
                            }) {
                                Text(cityName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedDestination == cityName ? Color.blue : Color(.systemGray6))
                                    .foregroundColor(selectedDestination == cityName ? .white : .blue)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(selectedDestination == cityName ? Color.clear : Color(UIColor.systemGray4).opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
    
            // 旅行天数
            VStack(alignment: .leading, spacing: 8) {
                Text("ai_planner.travel_days".localized())
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    
                    Text("ai_planner.total_days".localized())
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 天数选择器（带增减按钮）
                    HStack(spacing: 16) {
                        Button(action: {
                            if travelDays > 1 {
                                travelDays -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(travelDays > 1 ? .blue : .gray)
                        }
                        .disabled(travelDays <= 1)
                        
                        Text("ai_planner.days".localized(with: travelDays))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(minWidth: 50)
                        
                        Button(action: {
                            if travelDays < 30 {
                                travelDays += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(travelDays < 30 ? .blue : .gray)
                        }
                        .disabled(travelDays >= 30)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                )
            }
            
            // 同行人数
            VStack(alignment: .leading, spacing: 8) {
                Text("ai_planner.travelers".localized())
                    .font(.headline)
                
                VStack(spacing: 12) {
                    // 大人 - 独立容器
                    HStack {
                        // 左侧：文字信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ai_planner.adults".localized())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("ai_planner.adults_description".localized())
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 右侧：控制器（水平排列）
                        HStack(spacing: 16) {
                            // 减号按钮（圆形，灰色边框，蓝色图标）
                            Button(action: {
                                if adults > 1 {
                                    adults -= 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(adults > 1 ? Color.blue : Color(UIColor.systemGray4), lineWidth: 1.5)
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(adults > 1 ? .blue : Color(UIColor.systemGray3))
                                }
                            }
                            .disabled(adults <= 1)
                            
                            // 数字显示
                            Text("\(adults)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(minWidth: 30)
                            
                            // 加号按钮（圆形，蓝色填充，白色图标）
                            Button(action: {
                                if adults < 20 {
                                    adults += 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(adults < 20 ? Color.blue : Color(UIColor.systemGray4))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(adults >= 20)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                    )
                    
                    // 小孩 - 独立容器
                    HStack {
                        // 左侧：文字信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ai_planner.children".localized())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("ai_planner.children_description".localized())
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 右侧：控制器（水平排列）
                        HStack(spacing: 16) {
                            // 减号按钮（圆形，灰色边框，蓝色图标）
                            Button(action: {
                                if children > 0 {
                                    children -= 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(children > 0 ? Color.blue : Color(UIColor.systemGray4), lineWidth: 1.5)
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(children > 0 ? .blue : Color(UIColor.systemGray3))
                                }
                            }
                            .disabled(children <= 0)
                            
                            // 数字显示
                            Text("\(children)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(minWidth: 30)
                            
                            // 加号按钮（圆形，蓝色填充，白色图标）
                            Button(action: {
                                if children < 20 {
                                    children += 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(children < 20 ? Color.blue : Color(UIColor.systemGray4))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(children >= 20)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                    )
                }
            }
                }
            }
            
    // MARK: - 步骤2：偏好设置
    private var step2View: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            
            // 交通方式
            VStack(alignment: .leading, spacing: 16) {
                Text("ai_planner.transportation".localized())
                    .font(.system(size: 20, weight: .semibold))
                
                VStack(spacing: 12) {
                    ForEach(TransportationType.allCases, id: \.self) { transport in
                        TransportationCard(
                            type: transport,
                            isSelected: selectedTransportation == transport
                        ) {
                            selectedTransportation = transport
                        }
                    }
                }
            }
            
            // 修改内容：旅游主题模块（文案为用户语言，id 不展示）
            VStack(alignment: .leading, spacing: 12) {
                Text("行程风格（可选）")
                    .font(.system(size: 20, weight: .semibold))
                Text("决定节奏与密度；不选则根据行程主题、备注与同行自动匹配。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                ForEach(AITripGenerator.builtInTravelThemeModules, id: \.id) { module in
                    Button {
                        selectedTravelThemeModuleId = module.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(module.name).font(.subheadline).fontWeight(.semibold)
                                Text(module.summary).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedTravelThemeModuleId == module.id {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                            }
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedTravelThemeModuleId == module.id ? Color.blue : Color(UIColor.systemGray4), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 兴趣偏好
            VStack(alignment: .leading, spacing: 16) {
                Text("ai_planner.interests".localized())
                    .font(.system(size: 20, weight: .semibold))
                
                // 按钮布局（2列，与特殊限制一致）
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(InterestTag.allCases.prefix(6), id: \.self) { tag in
                        InterestTagButton(
                            tag: tag,
                            isSelected: selectedInterests.contains(tag)
                        ) {
                            if selectedInterests.contains(tag) {
                                selectedInterests.remove(tag)
                            } else {
                                selectedInterests.insert(tag)
                            }
                        }
                    }
                }
            }
            
            // 特殊限制
            VStack(alignment: .leading, spacing: 16) {
                Text("ai_planner.special_requirements".localized())
                    .font(.system(size: 20, weight: .semibold))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(SpecialRestriction.allCases, id: \.self) { restriction in
                        SpecialRestrictionButton(
                            restriction: restriction,
                            isSelected: selectedRestrictions.contains(restriction)
                        ) {
                            if selectedRestrictions.contains(restriction) {
                                selectedRestrictions.remove(restriction)
                            } else {
                                selectedRestrictions.insert(restriction)
                            }
                        }
                    }
                }
            }
            
            
            // 預算等級
            VStack(alignment: .leading, spacing: 16) {
                Text("ai_planner.budget_level".localized())
                    .font(.system(size: 20, weight: .semibold))
                
                Picker("預算等級", selection: $budgetLevel) {
                    ForEach(BudgetLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    
    // MARK: - 步骤3：行程細節優化
    private var step3View: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 标题和副标题
            VStack(alignment: .leading, spacing: 8) {
                Text("行程細節優化")
                    .font(.system(size: 28, weight: .bold))
                
                Text("微調細節,讓我們為您推薦最精確的地點。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 周邊特色
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text("周邊特色")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                if isLoadingSurroundingFeatures {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("正在搜尋周邊特色...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                } else if surroundingAttractions.isEmpty && customSurroundingTags.isEmpty {
                    Text("暫無周邊特色推薦")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // 计算最多可选择数量（天数+1），含 API 推薦與自訂標籤
                    let maxSelection = travelDays + 1
                    let currentSelectionCount = selectedSurroundingAttractions.count + customSurroundingTags.count
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // API 推薦的周邊特色
                        if !surroundingAttractions.isEmpty {
                            if currentSelectionCount > 0 {
                                Text("ai_planner.selected_attractions".localized(with: currentSelectionCount, maxSelection))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(surroundingAttractions) { attraction in
                                    let isSelected = selectedSurroundingAttractions.contains(attraction.id)
                                    let isDisabled = !isSelected && currentSelectionCount >= maxSelection
                                    SurroundingAttractionButton(
                                        attraction: attraction,
                                        isSelected: isSelected
                                    ) {
                                        if isSelected {
                                            selectedSurroundingAttractions.remove(attraction.id)
                                        } else if currentSelectionCount < maxSelection {
                                            selectedSurroundingAttractions.insert(attraction.id)
                                        }
                                    }
                                    .opacity(isDisabled ? 0.5 : 1.0)
                                    .disabled(isDisabled)
                                }
                            }
                        }
                        
                        // 自訂標籤區塊
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ai_planner.custom_tags".localized())
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                TextField("ai_planner.custom_tag_placeholder".localized(), text: $customTagInput)
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { addCustomTag() }
                                Button(action: { addCustomTag() }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(customTagInput.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                                }
                                .disabled(customTagInput.trimmingCharacters(in: .whitespaces).isEmpty || currentSelectionCount >= maxSelection)
                            }
                            if !customSurroundingTags.isEmpty {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                    ForEach(customSurroundingTags, id: \.self) { tag in
                                        Button(action: {
                                            customSurroundingTags.removeAll { $0 == tag }
                                            customTagItineraryNotes.removeValue(forKey: tag)
                                        }) {
                                            HStack(spacing: 4) {
                                                Text(tag)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption2)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundColor(.primary)
                                            .cornerRadius(16)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("請為每個自訂標籤填寫想安排的行程內容（必填）")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    ForEach(customSurroundingTags, id: \.self) { tag in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(tag)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                            TextField("例如：想去的區域、停留時間、體驗重點…", text: Binding(
                                                get: { customTagItineraryNotes[tag] ?? "" },
                                                set: { customTagItineraryNotes[tag] = $0 }
                                            ))
                                            .textFieldStyle(.roundedBorder)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            // 移除 onAppear 中的自动加载，改为在步骤1点击下一步时开始加载
            // 如果进入步骤3时还在加载，显示加载状态；如果已加载完成，显示结果
            // 行程節奏
            VStack(alignment: .leading, spacing: 16) {
                Text("行程節奏")
                    .font(.system(size: 20, weight: .semibold))
                
                VStack(spacing: 12) {
                    PaceOption(
                        title: "輕鬆",
                        description: "步調悠閒",
                        isSelected: selectedPace == .relaxed
                    ) {
                        selectedPace = .relaxed
                    }
                    
                    PaceOption(
                        title: "緊湊",
                        description: "不留遺憾",
                        isSelected: selectedPace == .tight
                    ) {
                        selectedPace = .tight
                    }
                }
            }
            
            
            // GPS定位位置
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("出發位置")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                // Switch: 切换自定义地址
                HStack {
                    Text(useCustomDepartureLocation ? "自定義地址" : "定位位置")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $useCustomDepartureLocation)
                        .labelsHidden()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                )
                
                // 根据 switch 状态显示不同的内容
                if useCustomDepartureLocation {
                    // 自定义地址模式
                    Button {
                        showDepartureLocationPicker = true
                    } label: {
                        HStack {
                            Image(systemName: customDepartureAddress.isEmpty ? "mappin.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(customDepartureAddress.isEmpty ? .blue : .green)
                            Text(customDepartureAddress.isEmpty ? "自定義地址" : customDepartureAddress)
                                .font(.subheadline)
                                .foregroundColor(customDepartureAddress.isEmpty ? .secondary : .primary)
                                .lineLimit(2)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(customDepartureAddress.isEmpty ? Color.blue : Color(UIColor.systemGray4), lineWidth: customDepartureAddress.isEmpty ? 1 : 1)
                        )
                    }
                } else {
                    // GPS定位模式
                    if isLocatingGPS {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("正在定位...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    } else if currentGPSLocation != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                // 显示名字+地址的组合格式
                                let displayText = buildGPSDisplayText(name: gpsLocationName, address: gpsLocationAddress)
                                Text(displayText.isEmpty ? "定位位置" : displayText)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Spacer()
                                Button("重新定位") {
                                    requestGPSLocation()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                        )
                    } else {
                        Button {
                            requestGPSLocation()
                        } label: {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .foregroundColor(.blue)
                                Text("定位位置")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                    }
                }
                
                // 出發日期／時間（與建立行程相同的日期時間按鈕）
                VStack(alignment: .leading, spacing: 8) {
                    Text("出發日期／時間")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    DateTimePickerView(
                        startDate: $departureTripStartDate,
                        startTime: $departureTripStartTime,
                        endDate: $departurePickerEndDate,
                        endTime: $departurePickerEndTime,
                        isAllDay: $departurePickerIsAllDay,
                        isHasEnd: $departurePickerIsHasEnd
                    )
                }
            }
            .onAppear {
                // 进入步骤3时，如果未使用自定义地址且未自动请求过GPS，则自动获取当前位置
                if !useCustomDepartureLocation && !hasAutoRequestedGPS && currentGPSLocation == nil {
                    hasAutoRequestedGPS = true
                    requestGPSLocation()
                }
            }
            
            // 住宿选择（统一地址搜索）
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "bed.double.fill")
                        .foregroundColor(.blue)
                    Text("住宿選擇")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                Button {
                    showAccommodationPicker = true
                } label: {
                    HStack {
                        Image(systemName: accommodationAddress.isEmpty ? "mappin.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(accommodationAddress.isEmpty ? .blue : .green)
                        if accommodationAddress.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("選擇住宿地址")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("可搜尋酒店或自選地址")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text(accommodationAddress)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accommodationAddress.isEmpty ? Color.blue : Color(UIColor.systemGray4), lineWidth: accommodationAddress.isEmpty ? 1 : 1)
                    )
                }
            }
            
            // 其他需求
            VStack(alignment: .leading, spacing: 16) {
                Text("其他需求")
                    .font(.system(size: 20, weight: .semibold))
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $additionalRequirements)
                        .frame(height: 100)
                        .padding(4)
                    
                    if additionalRequirements.isEmpty {
                        Text("還有其他想告訴AI的嗎?例如:不吃生食、對花粉過敏...")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - 步骤4：AI生成
    private var step4View: some View {
        VStack(spacing: 32) {
            // 中央图标
            ZStack {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            // 周围图标
            HStack(spacing: 40) {
                Image(systemName: "cloud")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
                
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                
                Image(systemName: "fork.knife")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                
                Image(systemName: "house.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
            
            // 标题和副标题
        VStack(spacing: 8) {
                Text("AI正在為您打造行程...")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("這個過程可能需要一些時間，請稍候")
                    .font(.subheadline)
                            .foregroundColor(.secondary)
                
                if let m = resolvedTravelThemeModule {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已套用：\(m.name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(travelIntensityDisplay(m.loadPolicy.intensity)) · \(m.summary)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("原则：每天少量核心安排，并预留交通、排队与休息。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
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
                    Text("正在完成您的行程")
                        .font(.subheadline)
                    Spacer()
                    Text("3/3")
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
                
                // 进度点
                HStack {
                    ForEach(0..<3) { index in
                            Circle()
                                .fill(index == 2 ? Color.blue : Color(UIColor.systemGray5))
                                .frame(width: 8, height: 8)
                    }
                            }
                        }
                    }
                }
                
    // MARK: - 底部按钮
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            if currentStep == .step1 {
                Button(action: {
                    goToNextStep()
                }) {
                    HStack {
                        Text("ai_planner.next_preferences".localized())
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(canProceedToStep2 ? Color.blue : Color.gray)
                    .cornerRadius(20)
                }
                .disabled(!canProceedToStep2)
            } else if currentStep == .step2 {
                HStack(spacing: 12) {
                    Button(action: {
                        goToPreviousStep()
                    }) {
                        Text("ai_planner.previous".localized())
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        goToNextStep()
                    }) {
                        Text("ai_planner.next".localized())
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }
            } else if currentStep == .step3 {
                // AI 生成付費開關
                Toggle(isOn: $enableAIGeneration) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("theme.enable_ai_generation".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("theme.ai_generation_premium_hint".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.blue)
                .padding(.vertical, 8)
                
                HStack(spacing: 12) {
                    Button(action: {
                        goToPreviousStep()
                    }) {
                        Text("ai_planner.previous".localized())
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        goToNextStep()
                    }) {
                        Text("ai_planner.complete_setup".localized())
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background((!customSurroundingTags.isEmpty && !customTagsItineraryComplete) ? Color.gray : Color.blue)
                            .cornerRadius(20)
                    }
                    .disabled(!customSurroundingTags.isEmpty && !customTagsItineraryComplete)
                }
            }
        }
        .padding()
                .background(Color(UIColor.systemBackground))
    }
    
    private var canProceedToStep2: Bool {
        return !destination.isEmpty && travelDays > 0
    }
    
    /// 有自訂標籤時，每個標籤皆需填寫行程說明
    private var customTagsItineraryComplete: Bool {
        customSurroundingTags.allSatisfy { tag in
            !(customTagItineraryNotes[tag]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }
    
    // MARK: - 辅助视图
    
    // 兴趣偏好按钮（与特殊限制按钮样式一致）
    struct InterestTagButton: View {
        let tag: InterestTag
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: tag.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .blue : .primary)
                    
                    Text(tag.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
            }
        }
    }
    
    // 交通方式卡片
    struct TransportationCard: View {
        let type: TransportationType
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(type.description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    }
                }
                .padding()
                .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
            }
        }
    }
    
    // 行程節奏选项
    struct PaceOption: View {
        let title: String
        let description: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    // 单选圆圈
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 12, height: 12)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
            }
        }
    }
    
    // 周邊特色按钮（新版本，使用 SurroundingAttraction）
    struct SurroundingAttractionButton: View {
        let attraction: SurroundingAttraction
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: attraction.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(attraction.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color(UIColor.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    // 周邊特色按钮（旧版本，保留用于兼容）
    struct SurroundingFeatureButton: View {
        let feature: SurroundingFeature
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(feature.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color(UIColor.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    // 特殊限制按钮
    struct SpecialRestrictionButton: View {
        let restriction: SpecialRestriction
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: restriction.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .blue : .primary)
                    
                    Text(restriction.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
            }
        }
    }
    
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
    
    // MARK: - 辅助方法
    
    /// 收起键盘
    private func hideKeyboard() {
        isTextFieldFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    // MARK: - GPS定位方法
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
                    
                    // 获取并保存用户所在国家（转换为中文）
                    if let country = placemark.country {
                        self.userCountryName = self.convertCountryToChinese(country)
                    }
                    
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
                } else {
                    self.gpsLocationName = ""
                    self.gpsLocationAddress = "位置: \(location.coordinate.latitude), \(location.coordinate.longitude)"
                }
            }
        }
    }
    
    // MARK: - 国家名称转换（英文转中文）
    private func convertCountryToChinese(_ englishCountry: String) -> String? {
        let dataManager = DestinationDataManager.shared
        
        // 先尝试直接搜索（支持简繁体英文）
        let matchedCountries = dataManager.searchCountries(englishCountry)
        if let matchedCountry = matchedCountries.first {
            return matchedCountry
        }
        
        // 如果搜索不到，尝试使用 DestinationData 中的映射
        // 这里可以扩展更多映射，但优先使用 searchCountries 因为它已经支持简繁体英文
        return nil
    }
    
    // MARK: - 构建GPS定位显示文本（名字+地址）
    private func buildGPSDisplayText(name: String, address: String) -> String {
        var components: [String] = []
        
        // 添加名字（如果存在且与地址不同）
        if !name.isEmpty && name != address {
            components.append(name)
        }
        
        // 添加地址（如果存在）
        if !address.isEmpty {
            components.append(address)
        }
        
        // 如果名字和地址相同，只显示一次
        if components.isEmpty && !name.isEmpty {
            return name
        }
        
        return components.joined(separator: " · ")
    }
    
    // 从历史记录中查找完整的目的地字符串（用于城市名匹配）
    private func findFullDestination(for cityName: String) -> String? {
        guard let history = try? JSONDecoder().decode([String].self, from: destinationHistoryData) else {
            return nil
        }
        // 查找包含该城市名的完整目的地字符串
        return history.first { dest in
            if dest.contains(" - ") {
                let components = dest.components(separatedBy: " - ")
                return components.last == cityName
            }
            return dest == cityName
        }
    }
    
    // 保存目的地到历史记录
    private func saveDestinationToHistory(_ destination: String) {
        guard !destination.isEmpty else { return }
        
        // 从历史记录中读取现有列表
        var history: [String] = []
        if let existingHistory = try? JSONDecoder().decode([String].self, from: destinationHistoryData) {
            history = existingHistory
        }
        
        // 移除重复项（如果已存在）
        history.removeAll { $0 == destination }
        
        // 将新目的地添加到最前面（最近使用的在前面）
        history.insert(destination, at: 0)
        
        // 限制历史记录数量（只保留最后4个，删除旧的）
        if history.count > 4 {
            history = Array(history.prefix(4))
        }
        
        // 保存回 UserDefaults
        if let encoded = try? JSONEncoder().encode(history) {
            destinationHistoryData = encoded
        }
    }
    
    // 清空周边特色（当目的地改变时调用）
    private func clearSurroundingFeatures() {
        surroundingAttractions = []
        selectedSurroundingAttractions = []
        lastLoadedDestination = ""
        isLoadingSurroundingFeatures = false
    }
    
    /// 新增自訂標籤（限於總選取數 travelDays+1 內）
    private func addCustomTag() {
        let trimmed = customTagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let maxSelection = travelDays + 1
        let currentCount = selectedSurroundingAttractions.count + customSurroundingTags.count
        guard currentCount < maxSelection else { return }
        guard !customSurroundingTags.contains(trimmed) else {
            customTagInput = ""
            return
        }
        customSurroundingTags.append(trimmed)
        customTagItineraryNotes[trimmed] = ""
        customTagInput = ""
    }
    
    // 通过 OpenAI API 获取周邊特色（带超时处理）
    private func loadSurroundingFeatures() {
        guard !destination.isEmpty else { return }
        
        // 如果目的地没有改变，且已有数据，则不重新加载
        if destination == lastLoadedDestination && !surroundingAttractions.isEmpty {
            return
        }
        
        isLoadingSurroundingFeatures = true
        
        Task {
            do {
                // 使用 withTimeout 包装，避免无限等待
                let attractions = try await withTimeout(seconds: 20) {
                    try await self.fetchSurroundingAttractions()
                }
                
                await MainActor.run {
                    self.surroundingAttractions = attractions
                    self.lastLoadedDestination = self.destination  // 更新上次加载的目的地
                    self.isLoadingSurroundingFeatures = false
                }
            } catch {
                print("❌ [AIPlannerView] 获取周边特色失败: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingSurroundingFeatures = false
                    // 如果失败，使用默认的特色（4-8个）
                    let defaultAttractions = self.getDefaultAttractions()
                    self.surroundingAttractions = Array(defaultAttractions.prefix(6)) // 默认返回6个
                    self.lastLoadedDestination = self.destination  // 即使失败也更新，避免重复请求
                }
            }
        }
    }
    
    // 超时包装函数
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // 添加实际任务
            group.addTask {
                try await operation()
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "AIPlannerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "请求超时"])
            }
            
            // 返回第一个完成的任务结果
            // 修复：避免 force unwrap，使用 guard let
            guard let result = try await group.next() else {
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "任务组返回空结果"])
            }
            group.cancelAll() // 取消其他任务
            return result
        }
    }
    
    // 调用 OpenAI API 获取周边特色（整合城市资料库和兴趣偏好权重）
    private func fetchSurroundingAttractions() async throws -> [SurroundingAttraction] {
        // 提取城市名（如果格式是"国家 - 城市"，只取城市部分）
        let cityName: String
        let countryName: String?
        if destination.contains(" - ") {
            let components = destination.components(separatedBy: " - ")
            countryName = components.first
            cityName = components.last ?? destination
        } else {
            cityName = destination
            countryName = nil
        }
        
        // 1. 首先尝试从城市资料库获取（优先使用资料库，避免重复API调用）
        let database = CityAttractionsDatabase.shared
        let interestTags = selectedInterests.map { $0.rawValue }
        let cityAttractions = database.getFilteredAttractions(
            for: cityName,
            country: countryName,
            interestTags: interestTags,
            sortBy: .popularity,
            referenceLocation: nil,
            routeLocations: [],
            excludeAttractions: [],
            maxDistance: nil,
            futureRouteLocations: []
        )
        
        // 2. 转换为SurroundingAttraction格式
        var attractions: [SurroundingAttraction] = cityAttractions.map { cityAttraction in
            SurroundingAttraction(
                id: cityAttraction.id,
                name: cityAttraction.name,
                category: cityAttraction.category,
                icon: cityAttraction.icon
            )
        }
        
        // 3. 如果资料库中没有足够的数据（少于6个），使用API补充
        if attractions.count < 6 {
            // 构建提示词，包含兴趣偏好（增加权重）
            var prompt = "推荐\(cityName)的4-8个知名地标或景点"
            if !interestTags.isEmpty {
                prompt += "，优先推荐与以下兴趣相关的：\(interestTags.joined(separator: "、"))"
            }
            prompt += "，只返回JSON数组：[\"景点1\",\"景点2\",...]"
            
            // 调用 OpenAI API（带超时处理）
            let response = try await OpenAIManager.shared.generateSurroundingAttractions(
                prompt: prompt,
                timeout: 30.0  // 国外目的地/网络延迟更高时容易超时，适当放宽
            )
            
            // 解析API响应
            let apiAttractions = parseSurroundingAttractions(response)
            
            // 合并并去重
            let existingNames = Set(attractions.map { $0.name.lowercased() })
            let newAttractions = apiAttractions.filter { attraction in
                !existingNames.contains(attraction.name.lowercased())
            }
            attractions.append(contentsOf: newAttractions)
        }
        
        // 4. 根据兴趣偏好重新排序（匹配兴趣的排在前面）
        if !interestTags.isEmpty {
            attractions.sort { attraction1, attraction2 in
                let match1 = attraction1.category.lowercased().contains(interestTags.joined(separator: " ").lowercased()) ||
                             interestTags.contains { tag in attraction1.category.lowercased().contains(tag.lowercased()) }
                let match2 = attraction2.category.lowercased().contains(interestTags.joined(separator: " ").lowercased()) ||
                             interestTags.contains { tag in attraction2.category.lowercased().contains(tag.lowercased()) }
                return match1 && !match2
            }
        }
        
        return Array(attractions.prefix(8))
    }
    
    // 解析周边特色响应（只包含名称的字符串数组）
    private func parseSurroundingAttractions(_ jsonString: String) -> [SurroundingAttraction] {
        // 首先尝试解析为字符串数组
        if let jsonData = jsonString.data(using: .utf8),
           let nameArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
            return parseAttractionsFromNameArray(nameArray)
        }
        
        // 如果失败，尝试提取JSON部分
        if let jsonStart = jsonString.range(of: "["),
           let jsonEnd = jsonString.range(of: "]", options: .backwards),
           let jsonSubstring = jsonString[jsonStart.lowerBound..<jsonEnd.upperBound].data(using: .utf8),
           let nameArray = try? JSONSerialization.jsonObject(with: jsonSubstring) as? [String] {
            return parseAttractionsFromNameArray(nameArray)
        }
        
        // 向后兼容：尝试解析为对象数组（旧格式）
        if let jsonData = jsonString.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
            return parseAttractionsFromObjectArray(jsonArray)
        }
        
        return getDefaultAttractions()
    }
    
    // 从名称数组解析周边特色（新格式）
    private func parseAttractionsFromNameArray(_ nameArray: [String]) -> [SurroundingAttraction] {
        var attractions: [SurroundingAttraction] = []
        
        for (index, name) in nameArray.enumerated() {
            guard !name.isEmpty else { continue }
            
            // 根据名称自动推断分类和图标
            let (category, icon) = inferCategoryAndIcon(from: name)
            
            let attraction = SurroundingAttraction(
                id: "\(index)",
                name: name,
                category: category,
                icon: icon
            )
            attractions.append(attraction)
        }
        
        // 接受4-8个结果，不强制补充
        // 如果少于4个，用默认值补充到至少4个
        if attractions.count < 4 {
            let defaultAttractions = getDefaultAttractions()
            let needed = 4 - attractions.count
            attractions.append(contentsOf: defaultAttractions.prefix(needed))
        }
        
        // 最多返回8个
        return Array(attractions.prefix(8))
    }
    
    // 从对象数组解析周边特色（向后兼容旧格式）
    private func parseAttractionsFromObjectArray(_ jsonArray: [[String: Any]]) -> [SurroundingAttraction] {
        var attractions: [SurroundingAttraction] = []
        
        for (index, dict) in jsonArray.enumerated() {
            guard let name = dict["name"] as? String,
                  !name.isEmpty else { continue }
            
            let category = dict["category"] as? String ?? "景点"
            let icon = dict["icon"] as? String ?? "location.circle"
            
            let attraction = SurroundingAttraction(
                id: "\(index)",
                name: name,
                category: category,
                icon: icon
            )
            attractions.append(attraction)
        }
        
        // 接受4-8个结果，不强制补充
        // 如果少于4个，用默认值补充到至少4个
        if attractions.count < 4 {
            let defaultAttractions = getDefaultAttractions()
            let needed = 4 - attractions.count
            attractions.append(contentsOf: defaultAttractions.prefix(needed))
        }
        
        // 最多返回8个
        return Array(attractions.prefix(8))
    }
    
    // 根据名称推断分类和图标
    private func inferCategoryAndIcon(from name: String) -> (category: String, icon: String) {
        let lowercasedName = name.lowercased()
        
        // 地标/建筑
        if lowercasedName.contains("塔") || 
           lowercasedName.contains("大樓") || lowercasedName.contains("大厦") ||
           lowercasedName.contains("tower") || lowercasedName.contains("building") {
            return ("地标", "building.2")
        }
        
        // 博物馆/文化
        if lowercasedName.contains("博物館") || lowercasedName.contains("博物馆") ||
           lowercasedName.contains("美術館") || lowercasedName.contains("美术馆") ||
           lowercasedName.contains("museum") || lowercasedName.contains("gallery") {
            return ("文化", "book")
        }
        
        // 寺庙/宗教
        if lowercasedName.contains("寺") || lowercasedName.contains("廟") ||
           lowercasedName.contains("神社") || lowercasedName.contains("temple") ||
           lowercasedName.contains("shrine") {
            return ("文化", "building.columns")
        }
        
        // 公园/自然
        if lowercasedName.contains("公園") || lowercasedName.contains("公园") ||
           lowercasedName.contains("park") ||
           lowercasedName.contains("山") || lowercasedName.contains("mountain") {
            return ("自然", "tree")
        }
        
        // 市场/购物
        if lowercasedName.contains("市場") || lowercasedName.contains("市场") ||
           lowercasedName.contains("商店街") || lowercasedName.contains("market") ||
           lowercasedName.contains("mall") {
            return ("购物", "bag")
        }
        
        // 美食
        if lowercasedName.contains("美食") || lowercasedName.contains("餐廳") ||
           lowercasedName.contains("餐厅") || lowercasedName.contains("restaurant") ||
           lowercasedName.contains("food") {
            return ("美食", "fork.knife")
        }
        
        // 默认
        return ("景点", "location.circle")
    }
    
    // 获取默认周边特色（作为备用）
    private func getDefaultAttractions() -> [SurroundingAttraction] {
        return [
            SurroundingAttraction(id: "default_1", name: "知名地标", category: "地标", icon: "building.2"),
            SurroundingAttraction(id: "default_2", name: "文化景点", category: "景点", icon: "building.columns"),
            SurroundingAttraction(id: "default_3", name: "自然景观", category: "景点", icon: "tree"),
            SurroundingAttraction(id: "default_4", name: "美食街区", category: "美食", icon: "fork.knife"),
            SurroundingAttraction(id: "default_5", name: "购物中心", category: "购物", icon: "bag"),
            SurroundingAttraction(id: "default_6", name: "艺术空间", category: "文化", icon: "paintpalette"),
            SurroundingAttraction(id: "default_7", name: "历史建筑", category: "历史", icon: "building"),
            SurroundingAttraction(id: "default_8", name: "观景台", category: "景点", icon: "binoculars"),
            SurroundingAttraction(id: "default_9", name: "主题公园", category: "娱乐", icon: "figure.play"),
            SurroundingAttraction(id: "default_10", name: "博物馆", category: "文化", icon: "book"),
            SurroundingAttraction(id: "default_11", name: "夜市", category: "美食", icon: "moon.stars"),
            SurroundingAttraction(id: "default_12", name: "特色街区", category: "景点", icon: "map")
        ]
    }
    
    // MARK: - 导航方法
    
    private func goToNextStep() {
        withAnimation {
            switch currentStep {
            case .step1:
                currentStep = .step2
                if !destination.isEmpty {
                    if destination != lastLoadedDestination || (surroundingAttractions.isEmpty && !isLoadingSurroundingFeatures) {
                        loadSurroundingFeatures()
                    }
                }
            case .step2:
                currentStep = .step3
                if !destination.isEmpty && destination != lastLoadedDestination {
                    loadSurroundingFeatures()
                }
            case .step3:
                if !customSurroundingTags.isEmpty {
                    let missing = customSurroundingTags.filter { tag in
                        (customTagItineraryNotes[tag]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    }
                    if !missing.isEmpty {
                        errorMessage = "請為每個自訂標籤填寫行程內容後再繼續。"
                        showErrorAlert = true
                        return
                    }
                }
                currentStep = .step4
                if !useCustomDepartureLocation && currentGPSLocation == nil && !isLocatingGPS {
                    requestGPSLocation()
                }
                startGeneration()
            case .step4:
                break
            }
        }
    }
    
    private func goToPreviousStep() {
        withAnimation {
            switch currentStep {
            case .step2:
                currentStep = .step1
            case .step3:
                currentStep = .step2
            case .step4:
                currentStep = .step3
            default:
                break
            }
        }
    }
    
    // MARK: - AI生成
    
    private func startGeneration() {
        guard !destination.isEmpty, travelDays > 0 else { return }
        
        guard enableAIGeneration else {
            errorMessage = "theme.ai_generation_premium_hint".localized()
            showErrorAlert = true
            return
        }
        
        currentStep = .step4
        isGenerating = true
        generationProgress = 0.0
        completedTasks = []
        currentTask = ""
        
        pendingTasks = [
            "正在尋找\(destination)附近的優質飯店",
            "正在分析目的地資訊",
            "正在規劃活動安排",
            "正在優化日期分配",
            "正在安排休息時間",
            "正在檢查景點開放時間",
            "正在優化每日路線",
            "正在生成完整行程"
        ]
        
        Task {
            await generatePlan()
        }
    }
    
    private func generatePlan() async {
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: departureTripStartDate)
        let startDate = combine(date: firstDay, time: departureTripStartTime)
        let lastDay = calendar.date(byAdding: .day, value: max(0, travelDays - 1), to: firstDay) ?? firstDay
        let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
        let dest = destination
        var slots = ExtractedSlots()
        slots.destination = SlotInfo(value: dest, confidence: 1.0)
        slots.dateRange = SlotInfo(value: DateRange(startDate: startDate, endDate: endDate), confidence: 1.0)
        slots.interestTags = selectedInterests.map { $0.rawValue }
        slots.budgetLevel = SlotInfo(value: budgetLevel, confidence: 1.0)
        slots.pace = SlotInfo(value: selectedPace, confidence: 1.0)
        if let transport = selectedTransportation {
            switch transport {
            case .publicTransport:
                slots.transportPreference = SlotInfo(value: .publicTransport, confidence: 1.0)
            case .selfDrive:
                slots.transportPreference = SlotInfo(value: .taxi, confidence: 0.8)
            case .charteredCar:
                slots.transportPreference = SlotInfo(value: .taxi, confidence: 1.0)
            }
        }
        
        let mergedCustomInstructions: String? = {
            var parts = [tripTheme, additionalRequirements].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let tagBlock = customSurroundingTags.compactMap { tag -> String? in
                let note = customTagItineraryNotes[tag]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !note.isEmpty else { return nil }
                return "【自訂標籤「\(tag)」行程內容】\(note)"
            }
            parts.append(contentsOf: tagBlock)
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        }()
        let request = GenerateRequest(
            plannerModelType: .multiPhase,
            generateMode: travelDays == 1 ? .singleDay : .multiDay,
            themeKey: "travel_planning",
            themeMode: .generateItinerary,
            userId: userManager.userOpenId.isEmpty ? nil : userManager.userOpenId,
            slots: slots,
            assumptions: [],
            riskFlags: [],
            npi: nil,
            customInstructions: mergedCustomInstructions,
            departureLocation: useCustomDepartureLocation ? (customDepartureCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }) : currentGPSLocation,
            accommodationAddress: accommodationAddress.isEmpty ? nil : accommodationAddress,
            accommodationCoordinate: accommodationCoordinate,
            selectedAttractionNames: surroundingAttractions.filter { selectedSurroundingAttractions.contains($0.id) }.map { $0.name },
            customSurroundingTags: customSurroundingTags,
            departureDateTime: startDate,
            adults: adults,
            children: children,
            planningDomain: .travel,
            planningIntensity: nil,
            travelThemeModuleId: self.resolvedTravelThemeId
        )
        
        let apiTask = Task {
            let result = try await GenerationOrchestrator.shared.generate(request: request)
            await MainActor.run {
                generatedResult = result
            }
        }
        
        // 任务列表动画（与 API 调用并行，不等待 API 响应）
        // 任务1: 分析目的地資訊
        await MainActor.run {
            currentTask = pendingTasks.removeFirst()
            generationProgress = 0.1
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 1秒
        
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.2
        }
        
        // 任务2: 規劃活動安排
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.35
        }
        
        // 任务3: 優化日期分配
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.5
        }
        
        // 任务4: 安排休息時間
        try? await Task.sleep(nanoseconds: 4_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.65
        }
        
        // 任务5: 檢查景點開放時間
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.8
        }
        
        // 任务6: 優化每日路線
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.9
        }
        
        // 任务7: 生成完整行程（等待 API 调用完成）
        await MainActor.run {
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
        }
        
        // 修复：统一错误处理，只在这里处理一次
        do {
            _ = try await apiTask.value
            await MainActor.run {
                if !currentTask.isEmpty {
                    completedTasks.append(currentTask)
                    currentTask = ""
                }
                generationProgress = 1.0
                isGenerating = false
                ActivityRecorder.recordAIUsed()
                if let result = generatedResult, let plan = result.plan {
                    savePlanToTemplate(plan, title: nil)
                }
            }
        } catch {
            // 统一错误处理（只在这里处理一次）
            await MainActor.run {
                if !currentTask.isEmpty {
                    currentTask = ""
                }
                // 提供更友好的错误信息
                let friendlyMessage: String
                if error.localizedDescription.contains("超时") || error.localizedDescription.contains("timed out") || error.localizedDescription.contains("timeout") {
                    friendlyMessage = "生成行程超时。OpenAI API 响应时间过长，请检查网络连接或稍后重试。"
                } else if error.localizedDescription.contains("quota") || error.localizedDescription.contains("billing") {
                    friendlyMessage = "OpenAI API 配额已用完。请检查账户余额或使用其他 API Key。"
                } else {
                    friendlyMessage = "生成行程失败：\(error.localizedDescription)"
                }
                errorMessage = friendlyMessage
                showErrorAlert = true
                isGenerating = false
            }
        }
    }
    
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: calendar.component(.second, from: time),
            of: date
        ) ?? date
    }
    
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    // MARK: - 保存到模板
    private func savePlanToTemplate(_ plan: PlanResult, title: String?) {
        let userId = userManager.userOpenId
        
        // 生成默认标题或使用提供的标题
        // 优先使用用户填写的 tripTheme，其次使用传入的 title，最后使用默认标题
        let templateTitle: String
        if let customTitle = title, !customTitle.isEmpty {
            templateTitle = customTitle
        } else if !tripTheme.isEmpty {
            templateTitle = tripTheme
        } else if let destination = SavedTripTemplate.extractDestination(from: plan) {
            templateTitle = "\(destination) \(plan.days.count)天行程"
        } else {
            templateTitle = "行程模板 \(plan.days.count)天"
        }
        
        // 提取目的地
        let destination = SavedTripTemplate.extractDestination(from: plan)
        
        // 创建模板
        let template = SavedTripTemplate(
            title: templateTitle,
            plan: plan,
            savedDate: Date(),
            tags: [],
            destination: destination
        )
        
        // 保存模板（不自动同步到行事历，用户需要在 PlanDetailView 中选择"加入行程"）
        TripTemplateManager.shared.saveTemplate(template, for: userId, syncToAppleCalendar: false)
        
        print("✅ 行程已保存到模板：\(templateTitle)")
    }
}

// MARK: - Preview（DateRangePickerView、CountryCityPickerView 與 AIPlannerView 共用，定義在 AIPlannerView.swift）
#Preview("旅遊行程") {
    TravelPlannerContent()
        .environmentObject(MockFirebaseUserManager.shared)
}
