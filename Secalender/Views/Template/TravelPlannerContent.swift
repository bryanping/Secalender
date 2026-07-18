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

// 共用類型（PlanningStep, SurroundingAttraction, InterestTag, SpecialRestriction, BudgetLevel 擴展）定義於 AIPlannerView.swift；特色體驗目錄見 TravelSpecialExperienceCatalog.swift。

/// 旅遊行程專用內容視圖：僅四步驟（目的地→偏好→細節→生成），無主題表單。
/// 修改内容：Step2 — 新增 customTheme：AIPlannerView 無表單主題流程改共用本視圖（刪除其重複四步驟實作），主題指令/路由鍵由此帶入。
struct TravelPlannerContent: View {
    var customTheme: QuickTheme? = nil
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    // 步骤控制
    @State private var currentStep: PlanningStep = .step1
    
    // 键盘焦点控制
    @FocusState private var isTextFieldFocused: Bool
    @FocusState private var isOtherInterestFocused: Bool
    
    // 步骤1：基本信息
    @State private var tripTheme: String = ""
    @State private var destination: String = ""
    @State private var selectedDestination: String? = nil  // 快速选择
    @State private var selectedCountry: String? = nil
    @State private var selectedCity: String? = nil
    @State private var showLocationPicker = false
    @State private var showTripDateRangePicker = false
    
    /// 旅行日期範圍（出發日／回程日，含首尾兩日）；天數由此推算
    @State private var tripRangeStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var tripRangeEndDate: Date = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    
    // 步骤2：偏好设置
    @State private var selectedInterests: Set<InterestTag> = []
    /// 正在為該興趣載入真實地點建議（`InterestTag.rawValue`）
    @State private var loadingInterestPlaceQueries: Set<String> = []
    // 修改内容：旅游主题模块（与 AITripGenerator 内建列表一致）
    @State private var selectedTravelThemeModuleId: String? = nil
    
    // 步骤3：行程細節優化
    @State private var surroundingAttractions: [SurroundingAttraction] = []
    @State private var selectedSurroundingAttractions: Set<String> = []  // 存储选中的ID
    /// 興趣偏好補充：可多選主題，載入額外 `supp_*` 推薦地點
    @State private var selectedSupplementKinds: Set<InterestPreferenceSupplementKind> = []
    /// 補充主題「其他」時必填，並作為 AI 地點建議提示
    @State private var supplementOtherNote: String = ""
    @State private var selectedRestrictions: Set<SpecialRestriction> = []
    @State private var additionalRequirements: String = ""
    
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
    
    /// 首日出發時刻（與出發日組合為 `departureDateTime`）
    @State private var departureTripStartTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    
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
    
    /// 含出發日與回程日在內的總天數（由日期範圍推算）
    private var computedTripDayCount: Int {
        let cal = Calendar.current
        let s = cal.startOfDay(for: tripRangeStartDate)
        let e = cal.startOfDay(for: tripRangeEndDate)
        let d = cal.dateComponents([.day], from: s, to: e).day ?? 0
        return max(1, d + 1)
    }
    
    private func clampTripEndDateIfNeeded() {
        let cal = Calendar.current
        let s = cal.startOfDay(for: tripRangeStartDate)
        let e = cal.startOfDay(for: tripRangeEndDate)
        if e < s {
            tripRangeEndDate = s
        }
    }
    
    // 修改内容：與 AITripGenerator.inferTravelThemeModuleId 單一數據源對齊（避免 UI 與生成器推断不一致）
    private func inferDefaultTravelThemeId() -> String {
        AITripGenerator.inferTravelThemeModuleId(
            children: 0,
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
                // 修改内容：Step2 — 帶入主題標題（原 AIPlannerView travel 流程行為）
                if let theme = customTheme, tripTheme.isEmpty {
                    tripTheme = theme.title
                }
            }
            .onChange(of: tripRangeStartDate) { _, _ in
                clampTripEndDateIfNeeded()
            }
            .onChange(of: tripRangeEndDate) { _, _ in
                clampTripEndDateIfNeeded()
            }
            .sheet(isPresented: $showTripDateRangePicker) {
                TravelDateRangePickerSheet(startDate: $tripRangeStartDate, endDate: $tripRangeEndDate)
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
                            if newDestination != destination {
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
                if oldValue != newValue {
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
                        },
                        // 修改内容：Time OS — 統一預覽：重新生成
                        onRegenerate: {
                            generatedResult = nil
                            startGeneration()
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
                                if newDestination != destination {
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
    
            // 旅行日期範圍（日曆區間選擇）；天數自動推算
            VStack(alignment: .leading, spacing: 12) {
       
                Button {
                    showTripDateRangePicker = true
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(TravelTripDateRangeDisplay.formattedLine(start: tripRangeStartDate, end: tripRangeEndDate))
                                .font(.body)
                                .foregroundColor(.primary)
                           
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                DatePicker("首日啟程時間", selection: $departureTripStartTime, displayedComponents: .hourAndMinute)
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                    Text("\(computedTripDayCount) 天行程")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(UIColor.systemGray4), lineWidth: 1)
            )
            
            step1LocationSections
        }
        .onAppear {
            if !useCustomDepartureLocation && !hasAutoRequestedGPS && currentGPSLocation == nil {
                hasAutoRequestedGPS = true
                requestGPSLocation()
            }
        }
    }
    
    /// 步驟一：出發位置與住宿（行程基礎）
    private var step1LocationSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text("出發位置")
                        .font(.system(size: 20, weight: .semibold))
                }
                
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
                
                if useCustomDepartureLocation {
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
            }
            
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
        }
    }
    
    // MARK: - 步骤2：偏好设置
    private var step2View: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 修改内容：旅游主题模块（文案为用户语言，id 不展示）
            VStack(alignment: .leading, spacing: 12) {
                Text("行程风格（可选）")
                    .font(.system(size: 20, weight: .semibold))
                Text("决定节奏与密度；不选则根据行程主题与备注自动匹配。")
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
                                removeInterestPlaceSuggestions(for: tag)
                            } else {
                                selectedInterests.insert(tag)
                                loadInterestPlaces(for: tag)
                            }
                        }
                    }
                    
                    Button {
                        if selectedSupplementKinds.contains(.other) {
                            selectedSupplementKinds.remove(.other)
                            supplementOtherNote = ""
                            removeSupplementPlaceSuggestions(for: .other)
                            isOtherInterestFocused = false
                        } else {
                            selectedSupplementKinds.insert(.other)
                            isOtherInterestFocused = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                                .foregroundColor(selectedSupplementKinds.contains(.other) ? .blue : .primary)
                            Text("其他")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedSupplementKinds.contains(.other) ? Color.blue.opacity(0.1) : Color(.systemBackground))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedSupplementKinds.contains(.other) ? Color.blue : Color(UIColor.systemGray4), lineWidth: selectedSupplementKinds.contains(.other) ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                if selectedSupplementKinds.contains(.other) {
                    TextField("請輸入其他興趣偏好（必填）", text: $supplementOtherNote, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                        .focused($isOtherInterestFocused)
                        .submitLabel(.done)
                        .onChange(of: supplementOtherNote) { _, newVal in
                            guard selectedSupplementKinds.contains(.other), !destination.isEmpty else { return }
                            let t = newVal.trimmingCharacters(in: .whitespacesAndNewlines)
                            if t.isEmpty {
                                removeSupplementPlaceSuggestions(for: .other)
                            } else {
                                loadSupplementPlaces(for: .other)
                            }
                        }
                }
            }
            
            if !selectedInterests.isEmpty {
                interestPlacesStep2Section
            }
            
            // 已合併到「興趣偏好」內的「其他」
        }
    }
    
    
    // MARK: - 步骤3：行程細節優化
    private var step3View: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 标题和副标题
            VStack(alignment: .leading, spacing: 8) {
                Text("行程細節優化")
                    .font(.system(size: 28, weight: .bold))
                
                Text("勾選限制條件，並補充想告知 AI 的細節。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 特殊需求與其他說明（合併）
            VStack(alignment: .leading, spacing: 16) {
                Text("特殊需求與其他說明")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("ai_planner.special_requirements".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $additionalRequirements)
                        .frame(height: 100)
                        .padding(4)
                    
                    if additionalRequirements.isEmpty {
                        Text("其他想告訴 AI 的細節：飲食禁忌、過敏、必去／避雷、體力限制…")
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
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }
            }
        }
        .padding()
                .background(Color(UIColor.systemBackground))
    }
    
    private var canProceedToStep2: Bool {
        let cal = Calendar.current
        let s = cal.startOfDay(for: tripRangeStartDate)
        let e = cal.startOfDay(for: tripRangeEndDate)
        return !destination.isEmpty && e >= s && computedTripDayCount >= 1
    }
    
    private var attractionAndTagPickCount: Int {
        selectedSurroundingAttractions.count
    }
    
    /// 寫入 `GenerateRequest.customSurroundingTags`，供生成器強制考量補充主題
    private var supplementThemeTagsForGeneration: [String] {
        selectedSupplementKinds.sorted { $0.rawValue < $1.rawValue }.compactMap { k -> String? in
            if k == .other {
                let n = supplementOtherNote.trimmingCharacters(in: .whitespacesAndNewlines)
                return n.isEmpty ? nil : "補充主題·其他：\(n)"
            }
            return "補充主題·\(k.promptLabelZh())"
        }
    }
    
    private var maxAttractionAndTagSelection: Int {
        computedTripDayCount + 1
    }
    
    private var interestPlacesStep2Section: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("興趣推薦地點")
                .font(.system(size: 20, weight: .semibold))
            Text(destination.isEmpty ? "請先在步驟一選擇目的地，將依資料庫與 AI 列出真實可查的地點，勾選後會納入行程生成。" : "可勾選納入行程")
                .font(.footnote)
                .foregroundColor(.secondary)
            ForEach(Array(selectedInterests).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { tag in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(tag.displayName) · 推薦地點")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if loadingInterestPlaceQueries.contains(tag.rawValue) {
                            ProgressView()
                                .scaleEffect(0.85)
                        }
                    }
                    interestPlaceGrid(for: tag)
                }
            }
        }
        .onAppear {
            for tag in selectedInterests {
                loadInterestPlaces(for: tag)
            }
        }
    }
    
    /// 興趣偏好補充：依主題再載入一批周邊推薦地點（與主興趣列共用勾選名額）
    private var interestPreferenceSupplementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("興趣偏好補充（可選）")
                    .font(.system(size: 20, weight: .semibold))
            }
            if !selectedSurroundingAttractions.isEmpty {
                Text("ai_planner.selected_attractions".localized(with: attractionAndTagPickCount, maxAttractionAndTagSelection))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button {
                toggleSupplementKind(.other)
            } label: {
                let isOn = selectedSupplementKinds.contains(.other)
                HStack(spacing: 8) {
                    Text("其他")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: isOn ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isOn ? Color.blue : Color(UIColor.systemGray4), lineWidth: isOn ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
            
            if selectedSupplementKinds.contains(.other) {
                TextField("請輸入你想補充的偏好（必填）", text: $supplementOtherNote, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: supplementOtherNote) { _, newVal in
                        guard selectedSupplementKinds.contains(.other), !destination.isEmpty else { return }
                        let t = newVal.trimmingCharacters(in: .whitespacesAndNewlines)
                        if t.isEmpty {
                            removeSupplementPlaceSuggestions(for: .other)
                        } else {
                            loadSupplementPlaces(for: .other)
                        }
                    }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("其他 · 推薦地點")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if loadingInterestPlaceQueries.contains(InterestPreferenceSupplementKind.other.loadingQueryKey) {
                            ProgressView()
                                .scaleEffect(0.85)
                        }
                    }
                    supplementPlaceGrid(for: .other)
                }
            }
        }
    }
    
    @ViewBuilder
    private func interestPlaceGrid(for tag: InterestTag) -> some View {
        let places = placesForInterest(tag)
        if places.isEmpty && !loadingInterestPlaceQueries.contains(tag.rawValue) {
            Text(destination.isEmpty ? "請先填寫目的地" : "此興趣暫無建議，可略過或換目的地再試")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(places) { attraction in
                    let isSelected = selectedSurroundingAttractions.contains(attraction.id)
                    let isDisabled = !isSelected && attractionAndTagPickCount >= maxAttractionAndTagSelection
                    SurroundingAttractionButton(
                        attraction: attraction,
                        isSelected: isSelected
                    ) {
                        if isSelected {
                            selectedSurroundingAttractions.remove(attraction.id)
                        } else if attractionAndTagPickCount < maxAttractionAndTagSelection {
                            selectedSurroundingAttractions.insert(attraction.id)
                        }
                    }
                    .opacity(isDisabled ? 0.5 : 1.0)
                    .disabled(isDisabled)
                }
            }
        }
    }
    
    @ViewBuilder
    private func supplementPlaceGrid(for kind: InterestPreferenceSupplementKind) -> some View {
        let places = placesForSupplementKind(kind)
        if kind == .other, supplementOtherNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("請填寫上方「其他」說明後，將載入推薦地點。")
                .font(.caption)
                .foregroundColor(.secondary)
        } else if places.isEmpty && !loadingInterestPlaceQueries.contains(kind.loadingQueryKey) {
            Text(destination.isEmpty ? "請先填寫目的地" : "此主題暫無建議，可略過或稍後再試")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(places) { attraction in
                    let isSelected = selectedSurroundingAttractions.contains(attraction.id)
                    let isDisabled = !isSelected && attractionAndTagPickCount >= maxAttractionAndTagSelection
                    SurroundingAttractionButton(
                        attraction: attraction,
                        isSelected: isSelected
                    ) {
                        if isSelected {
                            selectedSurroundingAttractions.remove(attraction.id)
                        } else if attractionAndTagPickCount < maxAttractionAndTagSelection {
                            selectedSurroundingAttractions.insert(attraction.id)
                        }
                    }
                    .opacity(isDisabled ? 0.5 : 1.0)
                    .disabled(isDisabled)
                }
            }
        }
    }
    
    private func supplementPrefix(_ kind: InterestPreferenceSupplementKind) -> String {
        "\(kind.placeIdPrefix)_"
    }
    
    private func placesForSupplementKind(_ kind: InterestPreferenceSupplementKind) -> [SurroundingAttraction] {
        let p = supplementPrefix(kind)
        return surroundingAttractions.filter { $0.id.hasPrefix(p) }
    }
    
    private func placesForInterest(_ tag: InterestTag) -> [SurroundingAttraction] {
        let p = "\(tag.rawValue)_"
        return surroundingAttractions.filter { $0.id.hasPrefix(p) }
    }
    
    private func removeInterestPlaceSuggestions(for tag: InterestTag) {
        let prefix = "\(tag.rawValue)_"
        let removedIds = Set(surroundingAttractions.filter { $0.id.hasPrefix(prefix) }.map(\.id))
        surroundingAttractions.removeAll { $0.id.hasPrefix(prefix) }
        selectedSurroundingAttractions.subtract(removedIds)
    }
    
    private func loadInterestPlaces(for interest: InterestTag) {
        guard !destination.isEmpty else { return }
        let key = interest.rawValue
        if loadingInterestPlaceQueries.contains(key) { return }
        loadingInterestPlaceQueries.insert(key)
        let destSnapshot = destination
        let exclude = Set(surroundingAttractions.map { $0.name.lowercased() })
        Task {
            do {
                let newPlaces = try await withTimeout(seconds: 25) {
                    try await TravelInterestPlaceSuggester.fetchPlaces(
                        destination: destSnapshot,
                        interest: interest,
                        excludeLowercasedNames: exclude
                    )
                }
                await MainActor.run {
                    loadingInterestPlaceQueries.remove(key)
                    guard destSnapshot == destination else { return }
                    guard selectedInterests.contains(interest) else { return }
                    let prefix = "\(interest.rawValue)_"
                    surroundingAttractions.removeAll { $0.id.hasPrefix(prefix) }
                    var seen = Set(surroundingAttractions.map { $0.name.lowercased() })
                    let merged = newPlaces.filter { seen.insert($0.name.lowercased()).inserted }
                    surroundingAttractions.append(contentsOf: merged)
                }
            } catch {
                print("❌ [TravelPlannerContent] 興趣地點建議失敗: \(error.localizedDescription)")
                await MainActor.run {
                    loadingInterestPlaceQueries.remove(key)
                }
            }
        }
    }
    
    private func toggleSupplementKind(_ kind: InterestPreferenceSupplementKind) {
        if selectedSupplementKinds.contains(kind) {
            selectedSupplementKinds.remove(kind)
            removeSupplementPlaceSuggestions(for: kind)
            if kind == .other {
                supplementOtherNote = ""
            }
        } else {
            selectedSupplementKinds.insert(kind)
            if kind == .other {
                let t = supplementOtherNote.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty {
                    loadSupplementPlaces(for: kind)
                }
            } else {
                loadSupplementPlaces(for: kind)
            }
        }
    }
    
    private func removeSupplementPlaceSuggestions(for kind: InterestPreferenceSupplementKind) {
        let prefix = supplementPrefix(kind)
        let removedIds = Set(surroundingAttractions.filter { $0.id.hasPrefix(prefix) }.map(\.id))
        surroundingAttractions.removeAll { $0.id.hasPrefix(prefix) }
        selectedSurroundingAttractions.subtract(removedIds)
        loadingInterestPlaceQueries.remove(kind.loadingQueryKey)
    }
    
    private func loadSupplementPlaces(for kind: InterestPreferenceSupplementKind) {
        guard !destination.isEmpty else { return }
        if kind == .other {
            let hint = supplementOtherNote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hint.isEmpty else { return }
        }
        let key = kind.loadingQueryKey
        if loadingInterestPlaceQueries.contains(key) { return }
        loadingInterestPlaceQueries.insert(key)
        let destSnapshot = destination
        let exclude = Set(surroundingAttractions.map { $0.name.lowercased() })
        let hintSnapshot = supplementOtherNote
        Task {
            do {
                let newPlaces = try await withTimeout(seconds: 25) {
                    try await TravelInterestPlaceSuggester.fetchSupplementPlaces(
                        destination: destSnapshot,
                        kind: kind,
                        otherUserHint: kind == .other ? hintSnapshot : nil,
                        excludeLowercasedNames: exclude
                    )
                }
                await MainActor.run {
                    loadingInterestPlaceQueries.remove(key)
                    guard destSnapshot == destination else { return }
                    guard selectedSupplementKinds.contains(kind) else { return }
                    if kind == .other {
                        let t = supplementOtherNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                    }
                    let prefix = supplementPrefix(kind)
                    surroundingAttractions.removeAll { $0.id.hasPrefix(prefix) }
                    var seen = Set(surroundingAttractions.map { $0.name.lowercased() })
                    let merged = newPlaces.filter { seen.insert($0.name.lowercased()).inserted }
                    surroundingAttractions.append(contentsOf: merged)
                }
            } catch {
                print("❌ [TravelPlannerContent] 補充主題地點建議失敗: \(error.localizedDescription)")
                await MainActor.run {
                    loadingInterestPlaceQueries.remove(key)
                }
            }
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
        loadingInterestPlaceQueries = []
        selectedSupplementKinds = []
        supplementOtherNote = ""
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
    
    // MARK: - 导航方法
    
    /// 離開步驟二前：若勾選「其他」但未填寫說明，視為未使用並清空狀態，避免擋住下一步。
    private func clearOtherSupplementIfEmptyBeforeLeavingStep2() {
        guard selectedSupplementKinds.contains(.other) else { return }
        let t = supplementOtherNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.isEmpty else { return }
        selectedSupplementKinds.remove(.other)
        supplementOtherNote = ""
        removeSupplementPlaceSuggestions(for: .other)
    }
    
    private func goToNextStep() {
        withAnimation {
            switch currentStep {
            case .step1:
                currentStep = .step2
            case .step2:
                clearOtherSupplementIfEmptyBeforeLeavingStep2()
                currentStep = .step3
            case .step3:
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
        guard !destination.isEmpty, computedTripDayCount > 0 else { return }

        // 修改内容：Step2 — 主題分流守衛（原 AIPlannerView 行為）：非 generateItinerary 不呼叫 AITripGenerator
        if let theme = customTheme, theme.themeMode != .generateItinerary {
            errorMessage = "theme_mode.no_itinerary".localized()
            showErrorAlert = true
            return
        }

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
        let firstDay = calendar.startOfDay(for: tripRangeStartDate)
        let lastDay = calendar.startOfDay(for: tripRangeEndDate)
        let startDate = combine(date: firstDay, time: departureTripStartTime)
        let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
        let dest = destination
        let dayCount = computedTripDayCount
        var slots = ExtractedSlots()
        slots.destination = SlotInfo(value: dest, confidence: 1.0)
        slots.dateRange = SlotInfo(value: DateRange(startDate: startDate, endDate: endDate), confidence: 1.0)
        slots.durationDays = SlotInfo(value: dayCount, confidence: 1.0)
        slots.interestTags = selectedInterests.map { $0.rawValue }
        slots.budgetLevel = SlotInfo(value: BudgetLevel.moderate, confidence: 1.0)
        slots.specialExperiencePreferenceTitles = TravelSpecialExperienceCatalog.flattenedPlacePromptLines(
            selectedIds: selectedSurroundingAttractions,
            allAttractions: surroundingAttractions
        )
        slots.plannerConstraintLines = selectedRestrictions.map { $0.aiPlannerConstraintLine }
        
        // 修改内容：Step2 — 主題指令置頂拼入；themeKey 依 customTheme 路由（原 AIPlannerView travel 流程行為）
        let mergedCustomInstructions: String? = {
            let parts = [customTheme?.aiInstruction ?? "", tripTheme, additionalRequirements].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        }()
        let request = GenerateRequest(
            plannerModelType: .multiPhase,
            generateMode: dayCount == 1 ? .singleDay : .multiDay,
            themeKey: customTheme.map { "custom_\($0.key)" } ?? "travel_planning",
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
            customSurroundingTags: supplementThemeTagsForGeneration,
            departureDateTime: startDate,
            adults: 1,
            children: 0,
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
