//
//  AIPlannerView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  重新设计：步骤式AI规划界面
//

import SwiftUI
import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 步骤枚举
enum PlanningStep: Int {
    case step1 = 1  // 基本信息
    case step2 = 2  // 偏好设置
    case step3 = 3  // 行程細節優化
    case step4 = 4  // AI生成
}


// MARK: - 交通方式枚举
enum TransportationType: String, CaseIterable {
    case publicTransport
    case selfDrive
    case charteredCar
    
    var icon: String {
        switch self {
        case .publicTransport: return "bus.fill"
        case .selfDrive: return "car.fill"
        case .charteredCar: return "person.fill"
        }
    }
    @MainActor
    var displayName: String {
        switch self {
        case .publicTransport: return "transport.public_transport".localized()
        case .selfDrive: return "transport.self_drive".localized()
        case .charteredCar: return "transport.chartered_car".localized()
        }
    }
    @MainActor
    var description: String {
        switch self {
        case .publicTransport: return "transport.public_transport_desc".localized()
        case .selfDrive: return "transport.self_drive_desc".localized()
        case .charteredCar: return "transport.chartered_car_desc".localized()
        }
    }
}

// MARK: - 周邊特色数据结构
struct SurroundingAttraction: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String  // 分类，如"地标"、"景点"、"美食"等
    let icon: String
    
    static func == (lhs: SurroundingAttraction, rhs: SurroundingAttraction) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 周邊特色枚举（保留用于兼容）
enum SurroundingFeature: String, CaseIterable {
    case localFestivals = "在地慶典"
    case hiddenGems = "隱藏秘境"
    case instagramSpots = "網美打卡"
    case artisticCafes = "文青咖啡"
    
    var icon: String {
        switch self {
        case .localFestivals: return "sparkles"
        case .hiddenGems: return "location.circle"
        case .instagramSpots: return "camera.fill"
        case .artisticCafes: return "cup.and.saucer.fill"
        }
    }
}

// MARK: - 特殊限制枚举
enum SpecialRestriction: String, CaseIterable {
    case childFriendly
    case wheelchairAccess
    case indoorPriority
    case earlyRest
    
    var icon: String {
        switch self {
        case .childFriendly: return "figure.child"
        case .wheelchairAccess: return "figure.roll"
        case .indoorPriority: return "house.fill"
        case .earlyRest: return "moon.fill"
        }
    }
    @MainActor
    var displayName: String {
        switch self {
        case .childFriendly: return "restriction.child_friendly".localized()
        case .wheelchairAccess: return "restriction.wheelchair_access".localized()
        case .indoorPriority: return "restriction.indoor_priority".localized()
        case .earlyRest: return "restriction.early_rest".localized()
        }
    }
}

// MARK: - 兴趣标签
enum InterestTag: String, CaseIterable {
    case food
    case history
    case nature
    case shopping
    case nightlife
    case art
//    case adventure = "冒險"
//    case wellness = "身心健康"
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .history: return "building.columns"
        case .nature: return "tree"
        case .shopping: return "bag"
        case .nightlife: return "wineglass"
        case .art: return "paintpalette"
//        case .adventure: return "figure.climbing"
//        case .wellness: return "figure.mind.and.body"
        }
    }
    @MainActor
    var displayName: String {
        switch self {
        case .food: return "interest.food".localized()
        case .history: return "interest.history".localized()
        case .nature: return "interest.nature".localized()
        case .shopping: return "interest.shopping".localized()
        case .nightlife: return "interest.nightlife".localized()
        case .art: return "interest.art".localized()
        }
    }
}

// MARK: - BudgetLevel 扩展（用于UI显示）
@MainActor
extension BudgetLevel {
    var displayName: String {
        switch self {
        case .low: return "budget.economy".localized()
        case .moderate: return "budget.standard".localized()
        case .high: return "budget.luxury".localized()
        }
    }
    
    var symbol: String {
        switch self {
        case .low: return "$"
        case .moderate: return "$$"
        case .high: return "$$$"
        }
    }
}

struct AIPlannerView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var themeManager = QuickThemeManager.shared
    
    /// 自定義主題（從快速主題進入時傳入）
    private let customTheme: QuickTheme?
    /// 入口預設的規劃模型（Welcome/主題入口傳入）
    private let initialPlannerModelType: PlannerModelType?
    private let initialThemeKey: String?
    
    init(plannerModelType: PlannerModelType? = nil, themeKey: String? = nil, customTheme: QuickTheme? = nil) {
        self.customTheme = customTheme
        self.initialPlannerModelType = plannerModelType
        self.initialThemeKey = themeKey
    }
    
    /// 是否為「模型驅動單頁」：無主題時為 true，有主題時維持原步驟流程
    private var isModelDrivenPage: Bool { customTheme == nil }
    
    /// 當前規劃模型類型（6 型態；有主題時可依入口預設）
    @State private var plannerModelType: PlannerModelType = .multiPhase
    
    // 步骤控制（僅在非模型驅動時使用）
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
    
    // 步骤3：行程細節優化
    @State private var surroundingAttractions: [SurroundingAttraction] = []
    @State private var selectedSurroundingAttractions: Set<String> = []  // 存储选中的ID
    @State private var customSurroundingTags: [String] = []  // 用戶自訂標籤
    @State private var customTagInput: String = ""  // 自訂標籤輸入框
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
    
    // 主題專屬表單模式：當 customTheme 有 formQuestions 時使用
    @State private var themeFormAnswers: [String: String] = [:]
    @State private var themeFormStartDate: Date = Date()
    @State private var themeFormDurationDays: Int = 7  // 計劃時長（天），用於非旅行主題
    
    // 模型驅動頁：共用基礎欄位（標題/目標、描述、日期、地點、偏好）
    @State private var baseTitle: String = ""
    @State private var baseDescription: String = ""
    @State private var baseStartDate: Date = Date()
    @State private var baseEndDate: Date = Date()
    @State private var baseStartTime: Date = Date()
    @State private var baseEndTime: Date = Date()
    @State private var baseIsAllDay: Bool = false
    @State private var baseIsHasEnd: Bool = true
    @State private var baseLocation: String = ""
    @State private var basePreferences: String = ""
    // 意圖導向：一句話輸入 → 解析結果 → 確認後才顯示表單
    @State private var naturalLanguageInput: String = ""
    @State private var parsedIntent: ParsedPlannerIntent? = nil
    @State private var hasConfirmedParsedIntent: Bool = false
    @State private var isParsingIntent: Bool = false
    // 任務拆解專屬
    @State private var taskDeadline: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var taskAvailableHoursPerDay: Double = 4
    @State private var taskPriorityStrategy: String = "by_deadline"
    @State private var taskComplexity: String = "medium"
    // 修改内容：多人協調表單與試算結果
    @State private var coordinationFormState = AvailabilityCoordinationFormState()
    @State private var coordinationPreviewResult: CoordinationResult?

    // AI 生成付費開關（預設關閉，開啟後需單獨付費）
    @State private var enableAIGeneration: Bool = false
    
    // 菜單欄：編輯、分享
    @State private var showEditThemeSheet = false
    @State private var showShareSheet = false
    
    /// 更新主題表單答案（強制觸發 SwiftUI 更新）
    private func updateThemeFormAnswer(_ id: String, value: String) {
        var copy = themeFormAnswers
        copy[id] = value
        themeFormAnswers = copy
    }
    
    /// 是否使用主題專屬表單（有 formQuestions 時為 true）
    private var useThemeFormMode: Bool {
        guard let theme = customTheme,
              let questions = theme.formQuestions,
              !questions.isEmpty else { return false }
        return true
    }
    
    /// 是否顯示固定「計劃開始日期」區塊（當 formQuestions 無 plan_start_date/start_date 時顯示）
    private var showFixedPlanDate: Bool {
        guard let q = customTheme?.formQuestions else { return true }
        return !ThemeFormReservedId.hasDateQuestion(in: q)
    }
    
    /// 是否顯示固定「計劃時長」區塊（當 formQuestions 無 duration 相關問題時顯示）
    private var showFixedPlanDuration: Bool {
        guard let q = customTheme?.formQuestions else { return true }
        return !ThemeFormReservedId.hasDurationQuestion(in: q)
    }
    
    /// 從 themeFormAnswers 解析計劃開始日期（當 formQuestions 含 plan_start_date/start_date 時）
    private var themeFormResolvedStartDate: Date {
        guard let q = customTheme?.formQuestions else { return themeFormStartDate }
        guard ThemeFormReservedId.hasDateQuestion(in: q) else { return themeFormStartDate }
        for id in ThemeFormReservedId.dateIds {
            if let s = themeFormAnswers[id], let d = ISO8601DateFormatter().date(from: s) {
                return d
            }
        }
        return themeFormStartDate
    }
    
    /// 從 themeFormAnswers 解析計劃時長（天數）
    private var themeFormResolvedDurationDays: Int {
        guard let q = customTheme?.formQuestions else { return themeFormDurationDays }
        guard ThemeFormReservedId.hasDurationQuestion(in: q) else { return themeFormDurationDays }
        for id in ThemeFormReservedId.durationDayIds {
            if let s = themeFormAnswers[id], let v = Int(s), v > 0 { return v }
        }
        for id in ThemeFormReservedId.durationWeekIds {
            if let s = themeFormAnswers[id], let v = Int(s), v > 0 { return v * 7 }
        }
        return themeFormDurationDays
    }
    
    /// 建立 NPI 並校驗（禁止直接拼接原始表單到 prompt）
    private func buildAndValidateNPI() -> (npi: LegacyNormalizedPlanningInput?, errors: [String]?) {
        guard let theme = customTheme, let questions = theme.formQuestions, !questions.isEmpty else {
            return (nil, ["無表單問題"])
        }
        let npi = NPIMapper.mapToNPI(
            formAnswers: themeFormAnswers,
            formQuestions: questions,
            themeTitle: theme.title,
            themeKey: theme.key,
            planType: .itinerary,
            fixedStartDate: themeFormResolvedStartDate,
            fixedDurationDays: themeFormResolvedDurationDays
        )
        let errors = NPIMapper.validateNPI(npi)
        let validNPI = errors.isEmpty ? npi : nil
        _ = NPIMapper.buildGenerationLog(
            themeKey: theme.key,
            npi: npi,
            rawFormAnswersCount: themeFormAnswers.count,
            validationErrors: errors
        )
        return (validNPI, errors.isEmpty ? nil : errors)
    }
    
    /// 分享內容：行程主題與目的地
    private var shareText: String {
        var parts: [String] = []
        if !tripTheme.isEmpty {
            parts.append("行程主題：\(tripTheme)")
        }
        if !destination.isEmpty {
            parts.append("目的地：\(destination)")
        }
        return parts.isEmpty ? "行程規劃" : parts.joined(separator: "\n")
    }
    
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isModelDrivenPage {
                    // 模型驅動單頁：選擇器 + 共用區 + 模型專屬區 + 生成按鈕
                    modelDrivenContent
                } else {
                    // 有主題時維持原步驟流程
                    VStack(spacing: 0) {
                        progressIndicator
                        ScrollView {
                            VStack(spacing: 24) {
                                switch currentStep {
                                case .step1:
                                    if useThemeFormMode {
                                        themeFormStepView
                                    } else {
                                        step1View
                                    }
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
                        .scrollDismissesKeyboard(.interactively)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                isTextFieldFocused = false
                                hideKeyboard()
                            }
                        )
                        bottomButtons
                    }
                }
            }
            .navigationTitle(
                isModelDrivenPage ? "智能規劃" : (
                    currentStep == .step1 ? "行程基礎" :
                    currentStep == .step2 ? "進階設定" :
                    currentStep == .step3 ? "行程細節" : "智能規劃"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isModelDrivenPage {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                        }
                    } else if currentStep != .step1 {
                        Button(action: { goToPreviousStep() }) {
                            Image(systemName: "chevron.left")
                        }
                    } else {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                
                // 僅自訂主題顯示右上角選單（編輯、分享），系統自帶主題不顯示
                if customTheme != nil, customTheme?.isBuiltIn == false, !isModelDrivenPage {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if currentStep == .step1 {
                            Menu {
                                Button(action: { showEditThemeSheet = true }) {
                                    Label("common.edit".localized(), systemImage: "pencil")
                                }
                                Button(action: { showShareSheet = true }) {
                                    Label("event_ui.share".localized(), systemImage: "square.and.arrow.up")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 20))
                            }
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
            .onAppear {
                if let theme = customTheme {
                    tripTheme = theme.title
                    if let questions = theme.formQuestions {
                        var updated = themeFormAnswers
                        for q in questions {
                            if updated[q.id] == nil, let dv = q.defaultValue, !dv.isEmpty {
                                updated[q.id] = dv
                            } else if updated[q.id] == nil, q.type == .number, let mv = q.minValue {
                                updated[q.id] = "\(mv)"
                            }
                        }
                        themeFormAnswers = updated
                    }
                }
                if isModelDrivenPage, let initial = initialPlannerModelType {
                    plannerModelType = initial
                }
            }
            .sheet(isPresented: $showEditThemeSheet) {
                if let theme = customTheme, !theme.isBuiltIn {
                    CreateTripTemplateView()
                        .environmentObject(userManager)
                } else {
                    QuickThemeManagementView()
                        .environmentObject(userManager)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [shareText])
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
    
    // MARK: - 模型驅動單頁內容（意圖導向：輸入 → 解析卡片 → 動態表單）
    private var modelDrivenContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    if !hasConfirmedParsedIntent {
                        if let intent = parsedIntent {
                            parsedResultCard(intent)
                        } else {
                            intentInputSection
                            suggestionChipsSection
                            if !naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(action: {
                                    let parsed = PlannerAutoRouter.resolveModel(input: naturalLanguageInput)
                                    parsedIntent = parsed
                                }) {
                                    HStack {
                                        Text("下一步")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    } else {
                        sharedFormSection
                        modelSpecificFormSection
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    isTextFieldFocused = false
                    hideKeyboard()
                }
            )
            if hasConfirmedParsedIntent {
                modelDrivenGenerateButton
            }
        }
    }

    /// 一句話輸入區（意圖導向入口）
    private var intentInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("你想安排什麼？")
                .font(.headline)
                .foregroundColor(.primary)
            TextField("例：明天台北親子行程、三天東京旅遊、一週內完成專案", text: $naturalLanguageInput, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .focused($isTextFieldFocused)
        }
    }

    /// 熱門建議 chips（點擊填入輸入框）
    private var suggestionChipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("熱門")
                .font(.subheadline)
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(["週末放鬆行程", "親子一日遊", "三天東京旅遊", "一週內完成專案"], id: \.self) { suggestion in
                        Button(action: { naturalLanguageInput = suggestion }) {
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    /// AI 解析結果卡片：類型、時間、地點、目標 + [修改] [繼續]
    private func parsedResultCard(_ intent: ParsedPlannerIntent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("AI 理解你的需求")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            VStack(alignment: .leading, spacing: 8) {
                labelRow("類型", intent.displayType)
                if let days = intent.durationDays, days > 0 {
                    labelRow("時間", "\(days) 天")
                } else if let hint = intent.durationHint {
                    labelRow("時間", hint)
                }
                if let loc = intent.location, !loc.isEmpty {
                    labelRow("地點", loc)
                } else if let lh = intent.locationHint {
                    labelRow("地點", lh)
                }
                if let goal = intent.goal, !goal.isEmpty {
                    labelRow("目標", goal)
                }
                // 修改内容：多人協調解析摘要
                if intent.modelType == .availabilityCoordination {
                    if !intent.participants.isEmpty {
                        labelRow("參與者", intent.participants.map(\.name).joined(separator: "、"))
                    }
                    if let m = intent.coordinationMode {
                        labelRow("協調模式", m.displayTitle)
                    }
                    labelRow("信心度", String(format: "%.0f%%", intent.confidence * 100))
                    if !intent.missingFields.isEmpty {
                        labelRow("待補欄位", intent.missingFields.map(\.rawValue).joined(separator: "、"))
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            HStack(spacing: 12) {
                Button(action: {
                    resetModelDrivenAfterIntentEdit()
                }) {
                    Text("修改")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: {
                    applyParsedIntentToForm(intent)
                    hasConfirmedParsedIntent = true
                }) {
                    Text("繼續")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func labelRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(title)：")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer(minLength: 0)
        }
    }

    /// 修改：回到步驟 1，保留輸入框文字，清空解析與表單預填（避免污染新一輪）
    private func resetModelDrivenAfterIntentEdit() {
        parsedIntent = nil
        hasConfirmedParsedIntent = false
        plannerModelType = .multiPhase
        baseTitle = ""
        baseDescription = ""
        baseLocation = ""
        destination = ""
        selectedCountry = nil
        selectedCity = nil
        travelDays = 3
        let cal = Calendar.current
        baseStartDate = Date()
        baseEndDate = Date()
        baseIsAllDay = false
        baseIsHasEnd = true
        taskDeadline = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        taskAvailableHoursPerDay = 4
        taskPriorityStrategy = "by_deadline"
        taskComplexity = "medium"
        selectedPace = .relaxed
        selectedTransportation = .publicTransport
        budgetLevel = .moderate
        coordinationFormState = AvailabilityCoordinationFormState() // 修改内容
        coordinationPreviewResult = nil // 修改内容
    }

    /// 解析結果寫入表單：僅補空欄；任務型清空旅遊欄位，旅遊型不動任務截止預設除非由旅遊流程覆寫
    private func applyParsedIntentToForm(_ intent: ParsedPlannerIntent) {
        plannerModelType = intent.modelType

        if baseTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseTitle = intent.goal ?? intent.rawInput
        }
        if baseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseDescription = intent.rawInput
        }

        switch intent.modelType {
        case .availabilityCoordination:
            // 修改内容：套用多人協調預填
            coordinationFormState.participants = intent.participants.isEmpty
                ? [ParsedParticipant(name: "我", role: .selfUser, isRequired: true)]
                : intent.participants
            if let dateRange = intent.dateRange {
                coordinationFormState.startDate = dateRange.start
                coordinationFormState.endDate = dateRange.end
            }
            coordinationFormState.durationMinutes = intent.meetingDurationMinutes ?? 60
            coordinationFormState.coordinationMode = intent.coordinationMode ?? .strictIntersection
            coordinationPreviewResult = nil
        case .floatingTask:
            destination = ""
            baseLocation = ""
            selectedCountry = nil
            selectedCity = nil
            let off = intent.taskDeadlineOffsetDays ?? 7
            taskDeadline = Calendar.current.date(byAdding: .day, value: off, to: Date()) ?? Date()
        default:
            if let loc = intent.location, !loc.isEmpty {
                if destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    destination = loc
                }
                if baseLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    baseLocation = loc
                }
            }
            let days: Int = {
                if let d = intent.durationDays, d > 0 { return min(max(d, 1), 30) }
                if intent.displayType == "主題規劃" { return 3 }
                return 1
            }()
            travelDays = days
            let cal = Calendar.current
            baseStartDate = Date()
            baseEndDate = cal.date(byAdding: .day, value: days - 1, to: baseStartDate) ?? baseStartDate
            baseIsAllDay = true
            baseIsHasEnd = true
            taskDeadline = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            if intent.pace == "packed" {
                selectedPace = .tight
            } else if intent.pace == "relaxed" {
                selectedPace = .relaxed
            }
        }
    }
    
    /// 中段：共用基礎資訊區（標題/目標、描述、日期、地點、偏好）
    private var sharedFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基礎資訊")
                .font(.headline)
                .foregroundColor(.primary)
            VStack(spacing: 12) {
                TextField("標題或目標", text: $baseTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                TextField("描述（選填）", text: $baseDescription, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                VStack(alignment: .leading, spacing: 8) {
                    Text("時間範圍")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    DateTimePickerView(
                        startDate: $baseStartDate,
                        startTime: $baseStartTime,
                        endDate: Binding(
                            get: { baseIsHasEnd ? baseEndDate : nil },
                            set: { if let d = $0 { baseEndDate = d } }
                        ),
                        endTime: Binding(
                            get: { baseIsHasEnd ? baseEndTime : nil },
                            set: { if let t = $0 { baseEndTime = t } }
                        ),
                        isAllDay: $baseIsAllDay,
                        isHasEnd: $baseIsHasEnd
                    )
                }
                TextField("地點（選填）", text: $baseLocation)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                TextField("偏好或備註", text: $basePreferences, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    /// 下段：依 plannerModelType 顯示模型專屬欄位（6 型）
    @ViewBuilder
    private var modelSpecificFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(modelSpecificSectionTitle)
                .font(.headline)
                .foregroundColor(.primary)
            switch plannerModelType {
            case .multiPhase:
                multiDayFields
            case .floatingTask:
                taskBreakdownFields
            case .availabilityCoordination:
                availabilityCoordinationSection // 修改内容
            case .availability, .recurring, .matching, .aiOptimization:
                timePlanningPlaceholderView
            }
        }
    }

    // 修改内容：多人協調動態表單
    private var availabilityCoordinationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("多人時間協調")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("參與者")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(coordinationFormState.participants) { participant in
                    HStack {
                        Text(participant.name)
                        Spacer()
                        Text(participant.role.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Button("新增參與者") {
                    var s = coordinationFormState
                    s.participants.append(
                        ParsedParticipant(name: "新參與者", role: .guest, isRequired: false)
                    )
                    coordinationFormState = s
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("日期範圍")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DatePicker("開始", selection: $coordinationFormState.startDate, displayedComponents: .date)
                DatePicker("結束", selection: $coordinationFormState.endDate, displayedComponents: .date)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("活動時長")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Stepper(value: $coordinationFormState.durationMinutes, in: 15...240, step: 15) {
                    Text("\(coordinationFormState.durationMinutes) 分鐘")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("協調模式")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("協調模式", selection: $coordinationFormState.coordinationMode) {
                    ForEach(CoordinationMode.allCases, id: \.self) { mode in
                        Text(mode.displayTitle).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("搜集方式")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("搜集方式", selection: $coordinationFormState.collectionMethod) {
                    ForEach(AvailabilityCollectionMethod.allCases, id: \.self) { method in
                        Text(method.displayTitle).tag(method)
                    }
                }
                .pickerStyle(.segmented)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("備註")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("例如：希望安排在白天、避免中午", text: $coordinationFormState.note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
            }
            if let preview = coordinationPreviewResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("試算 Top 3 候選時段（MVP：假設全員在範圍內皆可）")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(Array(preview.rankedCandidates.prefix(3))) { c in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Self.coordinationDateFormatter.string(from: c.start)) → \(Self.coordinationDateFormatter.string(from: c.end))")
                                .font(.subheadline)
                            Text("分數 \(String(format: "%.2f", c.score)) · 可到 \(c.availableParticipantIds.count) 人")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    private static let coordinationDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
    
    private var modelSpecificSectionTitle: String {
        switch plannerModelType {
        case .availability: return "區間可選型設定"
        case .floatingTask: return "彈性任務型設定"
        case .multiPhase: return "多階段型設定"
        case .recurring: return "反覆週期型設定"
        case .matching: return "協作撮合型設定"
        case .aiOptimization: return "自動優化型設定"
        case .availabilityCoordination: return "多人協調設定" // 修改内容
        }
    }
    
    /// 區間可選 / 反覆週期 / 撮合 / AI 優化 的佔位說明（進階設定即將推出）
    private var timePlanningPlaceholderView: some View {
        Text("此型態的進階設定即將推出，目前可使用上方基礎資訊與時間範圍生成。")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
    
    /// 單日：時間範圍、地區、預算、節奏
    private var singleDayFields: some View {
        VStack(spacing: 12) {
            destinationField
            HStack {
                Text("行程節奏")
                Spacer()
                Picker("", selection: $selectedPace) {
                    Text("輕鬆").tag(Pace.relaxed)
                    Text("緊湊").tag(Pace.tight)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            budgetField
        }
    }
    
    /// 多日：天數、住宿地、交通偏好、每日安排密度
    private var multiDayFields: some View {
        VStack(spacing: 12) {
            destinationField
            HStack {
                Text("天數")
                Spacer()
                Stepper("\(travelDays) 天", value: $travelDays, in: 1...30)
                    .padding()
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            HStack {
                Text("交通偏好")
                Spacer()
                Picker("", selection: $selectedTransportation) {
                    Text("大眾運輸").tag(TransportationType?.some(.publicTransport))
                    Text("自駕").tag(TransportationType?.some(.selfDrive))
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            HStack {
                Text("節奏")
                Spacer()
                Picker("", selection: $selectedPace) {
                    Text("輕鬆").tag(Pace.relaxed)
                    Text("緊湊").tag(Pace.tight)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            budgetField
        }
    }
    
    /// 任務拆解：截止日期、每日可用時數、任務複雜度、優先順序
    private var taskBreakdownFields: some View {
        VStack(spacing: 12) {
            HStack {
                Text("截止日期")
                Spacer()
                DatePicker("", selection: $taskDeadline, displayedComponents: .date)
                    .labelsHidden()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            HStack {
                Text("每日可用時數")
                Spacer()
                Text("\(Int(taskAvailableHoursPerDay)) 小時")
                Slider(value: $taskAvailableHoursPerDay, in: 1...12, step: 0.5)
                    .frame(width: 120)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            HStack {
                Text("優先順序")
                Spacer()
                Picker("", selection: $taskPriorityStrategy) {
                    Text("依截止日").tag("by_deadline")
                    Text("依重要性").tag("by_importance")
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            HStack {
                Text("任務複雜度")
                Spacer()
                Picker("", selection: $taskComplexity) {
                    Text("簡單").tag("low")
                    Text("中等").tag("medium")
                    Text("複雜").tag("high")
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private var destinationField: some View {
        Button(action: { showLocationPicker = true }) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
                Text(destination.isEmpty ? "選擇目的地" : destination)
                    .foregroundColor(destination.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var budgetField: some View {
        HStack {
            Text("預算")
            Spacer()
            Picker("", selection: $budgetLevel) {
                Text("低").tag(BudgetLevel.low)
                Text("中").tag(BudgetLevel.moderate)
                Text("高").tag(BudgetLevel.high)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    /// 底部：生成按鈕（組 GenerateRequest → GenerationOrchestrator）
    private var modelDrivenGenerateButton: some View {
        Button(action: { Task { await runModelDrivenGenerate() } }) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                // 修改内容：多人協調用不同按鈕文案
                Text(isGenerating
                     ? (plannerModelType == .availabilityCoordination ? "試算中…" : "生成中…")
                     : (plannerModelType == .availabilityCoordination ? "建立協調並試算" : "生成"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isGenerating ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(isGenerating)
        .padding()
    }
    
    /// 模型驅動頁：組裝 GenerateRequest 並呼叫 GenerationOrchestrator
    private func runModelDrivenGenerate() async {
        // 修改内容：多人協調不走行程／任務生成管線
        if plannerModelType == .availabilityCoordination {
            await runAvailabilityCoordinationGenerate()
            return
        }
        let needsDest = plannerModelType == .multiPhase
        let destValue = destination.isEmpty ? baseLocation : destination
        if needsDest && destValue.isEmpty {
            await MainActor.run {
                errorMessage = "請填寫目的地或地點"
                showErrorAlert = true
            }
            return
        }
        await MainActor.run { isGenerating = true }
        defer { Task { @MainActor in isGenerating = false } }
        let calendar = Calendar.current
        let start: Date = baseIsAllDay
            ? calendar.startOfDay(for: baseStartDate)
            : mergeDateWithTime(date: baseStartDate, time: baseStartTime)
        let end: Date = {
            if !baseIsHasEnd {
                return baseIsAllDay
                    ? calendar.date(bySettingHour: 23, minute: 59, second: 59, of: baseStartDate) ?? start
                    : calendar.date(byAdding: .hour, value: 1, to: start) ?? start
            }
            let endDay = baseEndDate > baseStartDate ? baseEndDate : baseStartDate
            return baseIsAllDay
                ? calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDay) ?? start
                : mergeDateWithTime(date: endDay, time: baseEndTime)
        }()
        let startDateForRange = calendar.startOfDay(for: start)
        let endDateForRange = end > start ? end : calendar.date(byAdding: .day, value: 1, to: start) ?? start
        var slots = ExtractedSlots()
        let dest = destValue.isEmpty ? "未填目的地" : destValue
        slots.destination = SlotInfo(value: dest, confidence: 1.0)
        slots.dateRange = SlotInfo(value: DateRange(startDate: startDateForRange, endDate: endDateForRange), confidence: 1.0)
        slots.interestTags = selectedInterests.map { $0.rawValue }
        slots.budgetLevel = SlotInfo(value: budgetLevel, confidence: 1.0)
        slots.pace = SlotInfo(value: selectedPace, confidence: 1.0)
        if let t = selectedTransportation {
            switch t {
            case .publicTransport: slots.transportPreference = SlotInfo(value: .publicTransport, confidence: 1.0)
            case .selfDrive, .charteredCar: slots.transportPreference = SlotInfo(value: .taxi, confidence: 0.9)
            }
        }
        let mode = GenerateRequest.deriveGenerateMode(from: plannerModelType)
        var taskBreakdownParams: TaskBreakdownParams? = nil
        if plannerModelType == .floatingTask {
            taskBreakdownParams = TaskBreakdownParams(
                deadline: taskDeadline,
                availableHoursPerDay: taskAvailableHoursPerDay,
                priorityStrategy: taskPriorityStrategy,
                taskComplexity: taskComplexity
            )
        }
        let request = GenerateRequest(
            plannerModelType: plannerModelType,
            generateMode: mode,
            themeKey: initialThemeKey ?? "smart_plan",
            themeMode: .generateItinerary,
            userId: userManager.userOpenId.isEmpty ? nil : userManager.userOpenId,
            title: baseTitle.isEmpty ? nil : baseTitle,
            description: baseDescription.isEmpty ? nil : baseDescription,
            startDate: start,
            endDate: end,
            location: baseLocation.isEmpty ? nil : baseLocation,
            preferences: basePreferences.isEmpty ? nil : [basePreferences],
            timezone: TimeZone.current,
            sourcePage: "AIPlannerView",
            slots: slots,
            assumptions: [],
            riskFlags: [],
            npi: nil,
            customInstructions: basePreferences.isEmpty ? nil : basePreferences,
            departureLocation: nil,
            accommodationAddress: nil,
            accommodationCoordinate: nil,
            selectedAttractionNames: [],
            customSurroundingTags: [],
            adults: adults,
            children: children,
            taskBreakdown: taskBreakdownParams
        )
        do {
            let result = try await GenerationOrchestrator.shared.generate(request: request)
            await MainActor.run {
                generatedResult = result
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    // 修改内容：組裝多人協調請求
    private func buildCoordinationRequest(currentUserId: String) -> CoordinationRequest {
        let t = baseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return CoordinationRequest(
            title: t.isEmpty ? "多人時間協調" : t,
            createdByUserId: currentUserId,
            participants: coordinationFormState.participants,
            coordinationMode: coordinationFormState.coordinationMode,
            collectionMethod: coordinationFormState.collectionMethod,
            targetDateRange: coordinationFormState.dateRange,
            requiredDurationMinutes: coordinationFormState.durationMinutes,
            timezoneIdentifier: coordinationFormState.timezoneIdentifier,
            note: {
                let n = coordinationFormState.note.trimmingCharacters(in: .whitespacesAndNewlines)
                return n.isEmpty ? nil : n
            }()
        )
    }

    // 修改内容：多人協調試算（debug 列印 + Top 3 顯示）
    private func runAvailabilityCoordinationGenerate() async {
        guard coordinationFormState.participants.count >= 2 else {
            await MainActor.run {
                errorMessage = "請至少兩位參與者（可點「新增參與者」）"
                showErrorAlert = true
            }
            return
        }
        let uid = userManager.userOpenId.isEmpty ? "local_user" : userManager.userOpenId
        let req = buildCoordinationRequest(currentUserId: uid)
        print("[CoordinationRequest] id=\(req.id) title=\(req.title) mode=\(req.coordinationMode.rawValue) durationMin=\(req.requiredDurationMinutes)")
        let responses: [AvailabilityResponse] = coordinationFormState.participants.map {
            AvailabilityResponse(
                participantId: $0.id,
                timeBlocks: [
                    AvailabilityBlock(
                        start: req.targetDateRange.start,
                        end: req.targetDateRange.end,
                        preference: .preferred
                    )
                ],
                responseStatus: .submitted
            )
        }
        await MainActor.run { isGenerating = true }
        defer { Task { @MainActor in isGenerating = false } }
        let result = AvailabilityIntersectionEngine.generateCandidates(request: req, responses: responses)
        await MainActor.run {
            coordinationPreviewResult = result
        }
    }
    
    /// 將「日期」與「時間」合併為單一 Date（用於 DateTimePickerView 產出）
    private func mergeDateWithTime(date: Date, time: Date) -> Date {
        let c = Calendar.current
        let h = c.component(.hour, from: time)
        let m = c.component(.minute, from: time)
        let s = c.component(.second, from: time)
        return c.date(bySettingHour: h, minute: m, second: s, of: date) ?? date
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
    
    // 修复：统一进度显示，改为 4 步，进度按 25/50/75/100 走（主題表單模式為 2 步）
    private var progressPercentage: Double {
        if useThemeFormMode {
            return currentStep == .step1 ? 50.0 : 100.0
        }
        switch currentStep {
        case .step1: return 25.0
        case .step2: return 50.0
        case .step3: return 75.0
        case .step4: return 100.0
        }
    }
    
    // 修复：统一步骤文本（主題表單模式為 2 步）
    private var stepDisplayText: String {
        if useThemeFormMode {
            return currentStep == .step1 ? "步驟 1/2" : "步驟 2/2"
        }
        switch currentStep {
        case .step1: return "步驟 1/4"
        case .step2: return "步驟 2/4"
        case .step3: return "步驟 3/4"
        case .step4: return "步驟 4/4"
        }
    }
    
    // MARK: - 主題專屬表單（當 customTheme 有 formQuestions 時顯示）
    private var themeFormStepView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(themeManager.welcomeTitle(for: customTheme))
                    .font(.system(size: 28, weight: .bold))
                Text(themeManager.welcomeSubtitle(for: customTheme))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 固定：計劃開始日期（僅當 formQuestions 未包含 plan_start_date/start_date 時顯示）
            if showFixedPlanDate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ai_planner.plan_start_date".localized())
                        .font(.headline)
                    DatePicker("", selection: $themeFormStartDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
            }
            
            // 固定：計劃時長（僅當 formQuestions 未包含 duration 相關問題時顯示）
            if showFixedPlanDuration {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ai_planner.plan_duration".localized())
                        .font(.headline)
                    HStack {
                        Button(action: { if themeFormDurationDays > 1 { themeFormDurationDays -= 1 } }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(themeFormDurationDays > 1 ? .blue : .gray)
                        }
                        .disabled(themeFormDurationDays <= 1)
                        Text("ai_planner.days".localized(with: themeFormDurationDays))
                            .font(.system(size: 18, weight: .semibold))
                            .frame(minWidth: 60)
                        Button(action: { if themeFormDurationDays < 365 { themeFormDurationDays += 1 } }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(themeFormDurationDays < 365 ? .blue : .gray)
                        }
                        .disabled(themeFormDurationDays >= 365)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20)
                }
            }
            
            // 動態：主題專屬問題
            if let questions = customTheme?.formQuestions {
                ForEach(questions) { q in
                    themeFormQuestionView(question: q)
                }
            }
        }
    }
    
    @ViewBuilder
    private func themeFormQuestionView(question: ThemeFormQuestion) -> some View {
        let labelText = (question.label.contains(".") ? question.label.localized() : question.label)
        let placeholderText = (question.placeholder?.contains(".") == true ? (question.placeholder ?? "").localized() : (question.placeholder ?? ""))
        VStack(alignment: .leading, spacing: 8) {
            Text(labelText)
                .font(.headline)
            
            switch question.type {
            case .text:
                TextField(placeholderText, text: Binding(
                    get: { themeFormAnswers[question.id] ?? question.defaultValue ?? "" },
                    set: { updateThemeFormAnswer(question.id, value: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                
            case .number:
                let minV = question.minValue ?? 0
                let maxV = question.maxValue ?? 999
                let binding = Binding(
                    get: { Int(themeFormAnswers[question.id] ?? question.defaultValue ?? "\(minV)") ?? minV },
                    set: { updateThemeFormAnswer(question.id, value: "\($0)") }
                )
                HStack {
                    Button(action: {
                        let v = binding.wrappedValue
                        if v > minV { binding.wrappedValue = v - 1 }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(binding.wrappedValue > minV ? .blue : .gray)
                    }
                    .disabled(binding.wrappedValue <= minV)
                    Text("\(binding.wrappedValue) \(question.unit ?? "")")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(minWidth: 80)
                    Button(action: {
                        let v = binding.wrappedValue
                        if v < maxV { binding.wrappedValue = v + 1 }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(binding.wrappedValue < maxV ? .blue : .gray)
                    }
                    .disabled(binding.wrappedValue >= maxV)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                
            case .select:
                if let options = question.options {
                    Picker(labelText, selection: Binding(
                        get: { themeFormAnswers[question.id] ?? question.defaultValue ?? "" },
                        set: { updateThemeFormAnswer(question.id, value: $0) }
                    )) {
                        Text("--").tag("")
                        ForEach(options, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
            case .multiSelect:
                if let options = question.options {
                    let selected = Set((themeFormAnswers[question.id] ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(options, id: \.self) { opt in
                            Button(action: {
                                var s = selected
                                if s.contains(opt) { s.remove(opt) } else { s.insert(opt) }
                                updateThemeFormAnswer(question.id, value: s.sorted().joined(separator: ", "))
                            }) {
                                Text(opt)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selected.contains(opt) ? Color.blue : Color(.systemGray6))
                                    .foregroundColor(selected.contains(opt) ? .white : .primary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
            case .date:
                let binding = Binding(
                    get: {
                        let s = themeFormAnswers[question.id]
                        return s.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
                    },
                    set: {
                        updateThemeFormAnswer(question.id, value: ISO8601DateFormatter().string(from: $0))
                    }
                )
                DatePicker(labelText, selection: binding, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
    }
    
    // MARK: - 步骤1：基本信息
    private var step1View: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 標題和副標題（依主題顯示專屬文案）
            VStack(alignment: .leading, spacing: 8) {
                Text(themeManager.welcomeTitle(for: customTheme))
                    .font(.system(size: 28, weight: .bold))
                
                Text(themeManager.welcomeSubtitle(for: customTheme))
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
                                        Button(action: { customSurroundingTags.removeAll { $0 == tag } }) {
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
                // 主題表單模式：顯示 AI 生成開關
                if useThemeFormMode {
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
                }
                
                Button(action: {
                    goToNextStep()
                }) {
                HStack {
                        Text(useThemeFormMode ? "ai_planner.start_generate".localized() : "ai_planner.next_preferences".localized())
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
        if useThemeFormMode {
            return themeFormResolvedDurationDays > 0
        }
        return !destination.isEmpty && travelDays > 0
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
                if useThemeFormMode {
                    currentStep = .step4
                    startGeneration()
                } else {
                    currentStep = .step2
                    if !destination.isEmpty {
                        if destination != lastLoadedDestination || (surroundingAttractions.isEmpty && !isLoadingSurroundingFeatures) {
                            loadSurroundingFeatures()
                        }
                    }
                }
            case .step2:
                currentStep = .step3
                if !destination.isEmpty && destination != lastLoadedDestination {
                    loadSurroundingFeatures()
                }
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
                currentStep = useThemeFormMode ? .step1 : .step3
            default:
                break
            }
        }
    }
    
    // MARK: - AI生成
    
    private func startGeneration() {
        if useThemeFormMode {
            guard themeFormResolvedDurationDays > 0 else { return }
        } else {
            guard !destination.isEmpty, travelDays > 0 else { return }
        }
        
        // 主題分流：非 generateItinerary 不呼叫 AITripGenerator（解決「天安門」問題）
        if let theme = customTheme, theme.themeMode != .generateItinerary {
            errorMessage = "theme_mode.no_itinerary".localized()
            showErrorAlert = true
            return
        }
        
        // AI 生成為進階功能，需勾選啟用（開啟後需單獨付費，付費邏輯可後接）
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
        
        // 初始化任务列表（主題模式用不同文案）
        let destText = useThemeFormMode ? (customTheme?.title ?? "計劃") : destination
        pendingTasks = useThemeFormMode ? [
            "正在分析\(destText)需求",
            "正在規劃時間安排",
            "正在優化分配",
            "正在生成完整計劃"
        ] : [
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
        let startDate: Date
        let endDate: Date
        let dest: String
        var slots = ExtractedSlots()
        
        if useThemeFormMode {
            let npi = buildAndValidateNPI()
            guard let validNPI = npi.npi else {
                await MainActor.run {
                    errorMessage = npi.errors?.joined(separator: "\n") ?? "表單驗證失敗"
                    showErrorAlert = true
                    isGenerating = false
                }
                return
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            startDate = dateFormatter.date(from: validNPI.start_date) ?? themeFormResolvedStartDate
            endDate = dateFormatter.date(from: validNPI.end_date) ?? calendar.date(byAdding: .day, value: max(1, themeFormResolvedDurationDays) - 1, to: startDate) ?? startDate
            let defaultCountry = userCountryName ?? "台灣"
            let defaultCity = (defaultCountry == "中国" || defaultCountry == "中國") ? "北京" : (defaultCountry == "日本") ? "東京" : "台北"
            dest = validNPI.destination ?? "\(defaultCountry) - \(defaultCity)"
            slots.destination = SlotInfo(value: dest, confidence: 1.0)
            slots.dateRange = SlotInfo(value: DateRange(startDate: startDate, endDate: endDate), confidence: 1.0)
            slots.interestTags = []
            slots.budgetLevel = SlotInfo(value: budgetLevel, confidence: 1.0)
            slots.pace = SlotInfo(value: selectedPace, confidence: 1.0)
        } else {
            startDate = Date()
            endDate = calendar.date(byAdding: .day, value: travelDays - 1, to: startDate) ?? startDate
            dest = destination
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
        }
        
        let themeKeyForRequest = customTheme != nil ? "custom_\(customTheme!.key)" : "travel_planning"
        let customInstructionsForRequest: String? = {
            var s = customTheme?.aiInstruction ?? ""
            if useThemeFormMode, let npi = buildAndValidateNPI().npi {
                let npiJson = NPIMapper.npiToPromptJSON(npi)
                s = (s.isEmpty ? "" : s + "\n\n") + "【標準輸入 NPI】\n\(npiJson)"
            }
            return s.isEmpty ? nil : s
        }()
        let modelType: PlannerModelType = .multiPhase
        let request = GenerateRequest(
            plannerModelType: modelType,
            generateMode: travelDays == 1 ? .singleDay : .multiDay,
            themeKey: themeKeyForRequest,
            themeMode: customTheme?.themeMode ?? .generateItinerary,
            userId: userManager.userOpenId.isEmpty ? nil : userManager.userOpenId,
            slots: slots,
            assumptions: [],
            riskFlags: [],
            npi: useThemeFormMode ? buildAndValidateNPI().npi : nil,
            customInstructions: customInstructionsForRequest,
            departureLocation: useCustomDepartureLocation ? (customDepartureCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }) : currentGPSLocation,
            accommodationAddress: accommodationAddress.isEmpty ? nil : accommodationAddress,
            accommodationCoordinate: accommodationCoordinate,
            selectedAttractionNames: surroundingAttractions.filter { selectedSurroundingAttractions.contains($0.id) }.map { $0.name },
            customSurroundingTags: customSurroundingTags,
            adults: adults,
            children: children
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

// MARK: - 日期范围选择器
struct DateRangePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date?
    @Binding var isDateRange: Bool
    
    var body: some View {
        Form {
            Section {
                Toggle("多日行程", isOn: $isDateRange)
            }
            
            Section(header: Text("開始日期")) {
                DatePicker(
                    "開始日期",
                    selection: $startDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
            }
            
            if isDateRange {
                Section(header: Text("結束日期")) {
                    DatePicker(
                        "結束日期",
                        selection: Binding(
                            get: { endDate ?? startDate },
                            set: { endDate = $0 }
                        ),
                        in: startDate...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                }
            }
        }
        .onChange(of: isDateRange) { oldValue, newValue in
            if !newValue {
                endDate = nil
            } else if endDate == nil {
                let calendar = Calendar.current
                endDate = calendar.date(byAdding: .day, value: 2, to: startDate) ?? startDate
            }
        }
    }
}

// MARK: - 国家-城市选择器
struct CountryCityPickerView: View {
    @Binding var selectedCountry: String?
    @Binding var selectedCity: String?
    var userCountry: String? = nil  // 用户所在国家（可选）
    var onSelect: (String, String) -> Void
    
    @State private var searchText: String = ""
    @State private var viewingCountry: String? = nil  // 使用国家名而不是索引
    
    // 使用共享的数据管理器
    private let dataManager = DestinationDataManager.shared
    
    private var filteredCountries: [String] {
        let allCountries: [String]
        if searchText.isEmpty {
            allCountries = dataManager.getAllCountries()
        } else {
            // 使用 DestinationDataManager 的搜索功能（支持简繁体英文）
            allCountries = dataManager.searchCountries(searchText)
        }
        
        // 如果有用户所在国家，将其排到最上面
        guard let userCountry = userCountry, !userCountry.isEmpty else {
            return allCountries
        }
        
        // 检查用户所在国家是否在列表中
        if let userCountryIndex = allCountries.firstIndex(of: userCountry) {
            var sortedCountries = allCountries
            // 移除用户所在国家
            sortedCountries.remove(at: userCountryIndex)
            // 将用户所在国家插入到最前面
            sortedCountries.insert(userCountry, at: 0)
            return sortedCountries
        }
        
        // 如果用户所在国家不在列表中，返回原列表
        return allCountries
    }
    
    /// 获取城市列表（简化：不做特殊处理）
    private func cities(for country: String) -> [String] {
        return dataManager.getCities(for: country)
    }
    
    /// 搜索城市（支持简繁体英文）
    private func searchCities(in country: String, searchTerm: String) -> [String] {
        if searchTerm.isEmpty {
            return cities(for: country)
        }
        return dataManager.searchCities(in: country, searchTerm: searchTerm)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜尋國家或城市...", text: $searchText)
            }
            .padding()
            .background(Color(.systemGray6))
            
            if let country = viewingCountry {
                // 显示城市列表（支持搜索）
                let filteredCities = searchCities(in: country, searchTerm: searchText)
                
                List {
                    Section(header: Text("選擇城市 - \(country)\(searchText.isEmpty ? "" : " (搜尋: \(searchText))")")) {
                        if filteredCities.isEmpty {
                            if searchText.isEmpty {
                                Text("暫無城市資料")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                Text("未找到匹配的城市")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        } else {
                            ForEach(filteredCities, id: \.self) { city in
                                Button(action: {
                                    selectedCountry = country
                                    selectedCity = city
                                    onSelect(country, city)
                                }) {
                                    HStack {
                                        Text(city)
                                        Spacer()
                                        if selectedCountry == country && selectedCity == city {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("返回") {
                            viewingCountry = nil
                            searchText = ""  // 返回时清空搜索
                        }
                    }
                }
            } else {
                // 显示国家列表
                List {
                    ForEach(filteredCountries, id: \.self) { country in
                        Button(action: {
                            viewingCountry = country
                        }) {
                            HStack {
                                Text(country)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("步骤一：基本信息") {
    AIPlannerView()
        .environmentObject(MockFirebaseUserManager.shared)
}

#Preview("深色模式") {
    AIPlannerView()
        .environmentObject(MockFirebaseUserManager.shared)
        .preferredColorScheme(.dark)
}
