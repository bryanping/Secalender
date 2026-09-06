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
    
    /// 供 AI 行程生成 prompt 使用（固定中文，與本地化顯示語意對齊）
    var aiPlannerConstraintLine: String {
        switch self {
        case .childFriendly: return "親子友善（步速、安全與兒童設施）"
        case .wheelchairAccess: return "無障礙／輪椅友善動線"
        case .indoorPriority: return "優先室內或可避雨場景"
        case .earlyRest: return "較早休息、避免過晚戶外高強度安排"
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
    // 修改内容：Time OS — 工作流入口（帶場景標題/模型/預設輸入）與自由一句話輸入
    private let workflow: PlannerWorkflow?
    private let initialInput: String?
    // 修改內容：統一入口 — 已在入口頁提交過一句話時，進頁自動解析，不再要求按第二次「下一步」
    private let autoParseInitialInput: Bool
    // 修改內容：常用安排 — 再次使用時沿用偏好（主題表單答案排除日期題；自由輸入沿用原句／地點／偏好）
    private let preset: PlanningPreset?
    @State private var appliedPresetName: String? = nil

    init(plannerModelType: PlannerModelType? = nil, themeKey: String? = nil, customTheme: QuickTheme? = nil, workflow: PlannerWorkflow? = nil, initialInput: String? = nil, autoParse: Bool = false, preset: PlanningPreset? = nil) {
        self.customTheme = customTheme
        self.initialPlannerModelType = plannerModelType ?? workflow?.modelType
        self.initialThemeKey = themeKey
        self.workflow = workflow
        self.initialInput = initialInput ?? preset?.inputs[PlanningPreset.Key.input]
        self.autoParseInitialInput = autoParse || (initialInput == nil && preset?.inputs[PlanningPreset.Key.input] != nil)
        self.preset = preset
    }
    
    /// 是否為「模型驅動單頁」：無主題時為 true，有主題時維持原步驟流程
    /// 修改内容：Step3 — collectAvailability 主題直接落模型驅動頁（預設多人時間協調），不走表單/行程流程
    private var isModelDrivenPage: Bool {
        customTheme == nil || customTheme?.themeMode == .collectAvailability
    }
    
    /// 當前規劃模型類型（6 型態；有主題時可依入口預設）
    @State private var plannerModelType: PlannerModelType = .multiPhase
    
    // 步骤控制（僅在非模型驅動時使用）
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
    
    /// 旅行日期範圍（主題步驟流；天數由此推算）
    @State private var tripRangeStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var tripRangeEndDate: Date = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    
    // 步骤2：偏好设置
    @State private var selectedInterests: Set<InterestTag> = []
    @State private var loadingInterestPlaceQueries: Set<String> = []
    @State private var budgetLevel: BudgetLevel = .moderate
    // 修改内容：travel theme module 选择（主题优先于单次 prompt）
    @State private var selectedTravelThemeModuleId: String? = nil
    
    // 步骤3：行程細節優化
    @State private var surroundingAttractions: [SurroundingAttraction] = []
    @State private var selectedSurroundingAttractions: Set<String> = []  // 存储选中的ID
    @State private var selectedSupplementKinds: Set<InterestPreferenceSupplementKind> = []
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
    @State private var showOptionalPreferences: Bool = false  // 修改內容：統一入口 — 選填欄位預設收合
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
    
    /// 從 themeFormAnswers 解析計劃開始日期
    /// 修改内容：Step1 — 改用 ThemeFormReservedId.resolveStartDate 集中解析（role 優先、id 回退）
    private var themeFormResolvedStartDate: Date {
        guard let q = customTheme?.formQuestions else { return themeFormStartDate }
        return ThemeFormReservedId.resolveStartDate(questions: q, answers: themeFormAnswers) ?? themeFormStartDate
    }

    /// 從 themeFormAnswers 解析計劃時長（天數）
    /// 修改内容：Step1 — 改用 ThemeFormReservedId.resolveDurationDays 集中解析（週題自動 ×7）
    private var themeFormResolvedDurationDays: Int {
        guard let q = customTheme?.formQuestions else { return themeFormDurationDays }
        return ThemeFormReservedId.resolveDurationDays(questions: q, answers: themeFormAnswers) ?? themeFormDurationDays
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
        if e < s { tripRangeEndDate = s }
    }
    
    /// 模型驅動頁：依 base 起迄日推算總天數（含首尾）
    private var modelDrivenTripDayCount: Int {
        let cal = Calendar.current
        let s = cal.startOfDay(for: baseStartDate)
        let e = cal.startOfDay(for: baseEndDate)
        let d = cal.dateComponents([.day], from: s, to: e).day ?? 0
        return max(1, d + 1)
    }
    
    private func clampModelDrivenDateRange() {
        let cal = Calendar.current
        let s = cal.startOfDay(for: baseStartDate)
        let e = cal.startOfDay(for: baseEndDate)
        if e < s { baseEndDate = s }
    }
    
    var body: some View {
        // 修改内容：Step2 — 無表單主題（travel 四步驟）改共用 TravelPlannerContent，本檔僅保留：模型驅動單頁 + 主題表單流程
        // 修改内容：Step3 — 僅 generateItinerary 主題導向 TravelPlannerContent；floatingTasks 走表單→任務拆解；collectAvailability 走模型驅動頁
        if let theme = customTheme, theme.themeMode == .generateItinerary, !useThemeFormMode {
            TravelPlannerContent(customTheme: customTheme, preset: preset)  // 修改內容：常用安排
                .environmentObject(userManager)
        } else {
            mainNavigationContent
        }
    }

    private var mainNavigationContent: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if isModelDrivenPage {
                    // 模型驅動單頁：選擇器 + 共用區 + 模型專屬區 + 生成按鈕
                    modelDrivenContent
                } else {
                    // 主題表單流程：表單（step1）→ 生成（step4）
                    VStack(spacing: 0) {
                        progressIndicator
                        ScrollView {
                            VStack(spacing: 24) {
                                switch currentStep {
                                case .step1:
                                    themeFormStepView
                                case .step4:
                                    step4View
                                default:
                                    EmptyView()
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
                // 修改内容：Time OS — 場景標題優先
                isModelDrivenPage ? (workflow?.title ?? "智能規劃") : (
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
            .onChange(of: tripRangeStartDate) { _, _ in clampTripEndDateIfNeeded() }
            .onChange(of: tripRangeEndDate) { _, _ in clampTripEndDateIfNeeded() }
            .onChange(of: baseStartDate) { _, _ in clampModelDrivenDateRange() }
            .onChange(of: baseEndDate) { _, _ in clampModelDrivenDateRange() }
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
                // 修改内容：Step3 — collectAvailability 主題預設多人時間協調模型
                if customTheme?.themeMode == .collectAvailability {
                    plannerModelType = .availabilityCoordination
                }
                // 修改内容：Time OS — 工作流預填一句話；自由輸入直接帶入
                if naturalLanguageInput.isEmpty {
                    if let seed = workflow?.seedInput, !seed.isEmpty {
                        naturalLanguageInput = seed
                    } else if let input = initialInput, !input.isEmpty {
                        naturalLanguageInput = input
                    }
                }
                // 修改内容：Step A — startsAtForm 工作流（拆解目標）跳過一句話輸入頁，直落結構化表單
                if let wf = workflow, wf.startsAtForm, isModelDrivenPage {
                    plannerModelType = wf.modelType
                    hasConfirmedParsedIntent = true
                }
                // 修改內容：常用安排 — 沿用偏好（只填空欄；日期題不帶入）
                if let p = preset, appliedPresetName == nil {
                    applyPreset(p)
                }
                // 修改內容：統一入口 — 入口頁已提交的一句話直接解析並帶入表單
                if autoParseInitialInput, isModelDrivenPage, !hasConfirmedParsedIntent, parsedIntent == nil,
                   !naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    parseIntentAndFillForm()
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
                        // 修改内容：Time OS — 統一預覽：重新生成＋多人協作發送確認
                        onRegenerate: {
                            generatedResult = nil
                            if isModelDrivenPage {
                                Task { await runModelDrivenGenerate() }
                            } else {
                                startGeneration()
                            }
                        },
                        isCollaborative: workflow?.isCollaborative ?? (plannerModelType == .availabilityCoordination),
                        presetDraft: buildPresetDraft()  // 修改內容：常用安排
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
                    if !hasConfirmedParsedIntent && autoParseInitialInput && isParsingIntent {
                        // 修改內容：統一入口 — 自動解析中：顯示原句與進度，不再呈現輸入頁
                        VStack(alignment: .leading, spacing: 12) {
                            Text(naturalLanguageInput)
                                .font(.system(size: 17, weight: .medium))
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("正在理解你的需求…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    } else if !hasConfirmedParsedIntent {
                        // 修改内容：Step4 UX — 歡迎標題（對齊「行程規劃」28pt 標題＋副標）；Time OS 工作流顯示場景標題
                        VStack(alignment: .leading, spacing: 8) {
                            Text(workflow?.title ?? "智能規劃")
                                .font(.system(size: 28, weight: .bold))
                            Text(workflow?.subtitle ?? "一句話描述，AI 幫你安排")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        intentInputSection
                        suggestionChipsSection
                        if !naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // 修改内容：Step5 — 意圖解析主路徑改 LLM 分類（多語言），關鍵詞路由為 fallback
                            // 修改内容：解析後直接帶入基礎資訊填寫，跳過「AI 理解你的需求」確認頁
                            Button(action: { parseIntentAndFillForm() }) {  // 修改內容：統一入口 — 與自動解析共用
                                HStack {
                                    if isParsingIntent {
                                        ProgressView()
                                            .tint(.white)
                                        Text("解析中…")
                                            .fontWeight(.semibold)
                                    } else {
                                        Text("下一步")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(isParsingIntent)
                        }
                    } else {
                        // 修改内容：AI 理解摘要橫幅（可重新輸入），下方即基礎資訊表單（已預填 AI 理解內容）
                        if let intent = parsedIntent {
                            aiUnderstandingBanner(intent)
                        }
                        presetBanner  // 修改內容：常用安排
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

    // MARK: - 修改內容：常用安排 — 保存／沿用
    private var dateQuestionIds: Set<String> {
        guard let qs = customTheme?.formQuestions else { return [] }
        return Set(qs.filter { ThemeFormReservedId.isDateQuestion($0) || ThemeFormReservedId.isDurationDayQuestion($0) || ThemeFormReservedId.isDurationWeekQuestion($0) }.map(\.id))
    }

    /// 本次標準化輸入（主題表單：答案排除日期／天數題；模型驅動：原句、標題、地點、偏好）
    private func buildPresetDraft() -> PlanningPreset {
        var inputs: [String: String] = [:]
        let kind: PlanningPresetKind
        if let theme = customTheme, !isModelDrivenPage {
            kind = .themeForm
            let answers = themeFormAnswers.filter { !dateQuestionIds.contains($0.key) && !$0.value.isEmpty }
            if let data = try? JSONSerialization.data(withJSONObject: answers), let json = String(data: data, encoding: .utf8) {
                inputs[PlanningPreset.Key.formAnswers] = json
            }
            if let destQ = theme.formQuestions?.first(where: { $0.role == .destination }), let dest = answers[destQ.id] {
                inputs[PlanningPreset.Key.destination] = dest
            }
            inputs[PlanningPreset.Key.title] = theme.title
        } else {
            kind = .freeInput
            let raw = naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty { inputs[PlanningPreset.Key.input] = raw }
            if !baseTitle.isEmpty { inputs[PlanningPreset.Key.title] = baseTitle }
            if !baseLocation.isEmpty { inputs[PlanningPreset.Key.destination] = baseLocation }
            if !basePreferences.isEmpty { inputs[PlanningPreset.Key.notes] = basePreferences }
            inputs[PlanningPreset.Key.budget] = budgetLevel.rawValue
        }
        var draft = PlanningPreset(
            id: preset?.id ?? UUID().uuidString,
            name: preset?.name ?? PlanningPreset.defaultName(kind: kind, inputs: inputs),
            kind: kind,
            themeKey: customTheme?.key ?? initialThemeKey,
            inputs: inputs
        )
        if let p = preset { draft.createdAt = p.createdAt; draft.useCount = p.useCount }
        return draft
    }

    /// 沿用偏好：只填空欄，不動日期／天數題
    private func applyPreset(_ p: PlanningPreset) {
        let i = p.inputs
        if let json = i[PlanningPreset.Key.formAnswers],
           let data = json.data(using: .utf8),
           let saved = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] {
            var updated = themeFormAnswers
            let skip = dateQuestionIds
            for (k, v) in saved where !skip.contains(k) && (updated[k] ?? "").isEmpty {
                updated[k] = v
            }
            themeFormAnswers = updated
        }
        if baseLocation.isEmpty, let v = i[PlanningPreset.Key.destination] { baseLocation = v; if destination.isEmpty { destination = v } }
        if basePreferences.isEmpty, let v = i[PlanningPreset.Key.notes] { basePreferences = v }
        if let b = i[PlanningPreset.Key.budget], let lvl = BudgetLevel(rawValue: b) { budgetLevel = lvl }
        appliedPresetName = p.name
    }

    @ViewBuilder
    private var presetBanner: some View {
        if let name = appliedPresetName {
            HStack(spacing: 10) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("已沿用「\(name)」的偏好")
                        .font(.subheadline.weight(.medium))
                    Text("請確認本次日期；其他欄位可直接修改")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(12)
        }
    }

    /// 修改內容：統一入口 — 解析一句話並帶入表單（手動「下一步」與入口自動解析共用）
    private func parseIntentAndFillForm() {
        guard !isParsingIntent else { return }
        let inputText = naturalLanguageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !inputText.isEmpty else { return }
        isParsingIntent = true
        Task {
            let parsed = await PlannerIntentClassifier.shared.parse(input: inputText)
            await MainActor.run {
                parsedIntent = parsed
                applyParsedIntentToForm(parsed)
                hasConfirmedParsedIntent = true
                isParsingIntent = false
            }
        }
    }

    /// 一句話輸入區（意圖導向入口）
    /// 修改内容：Step4 UX — 改用 StandardFormUnit 卡片＋標準輸入樣式（原 roundedBorder 疊 padding 造成雙框）
    private var intentInputSection: some View {
        StandardFormUnit(title: "你想安排什麼？", isRequired: true) {
            TextField("例：明天台北親子行程、三天東京旅遊、一週內完成專案", text: $naturalLanguageInput, axis: .vertical)
                .lineLimit(2...5)
                .focused($isTextFieldFocused)
                .standardFieldContainer()
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

    /// 修改内容：AI 理解摘要橫幅（取代原「AI 理解你的需求」整頁卡片；內容已預填至下方表單）
    private func aiUnderstandingBanner(_ intent: ParsedPlannerIntent) -> some View {
        let parts: [String] = {
            var p = [intent.displayType]
            if let days = intent.durationDays, days > 0 { p.append("\(days) 天") }
            if let loc = intent.location, !loc.isEmpty { p.append(loc) }
            if intent.modelType == .availabilityCoordination, !intent.participants.isEmpty {
                p.append(intent.participants.map(\.name).joined(separator: "、"))
            }
            return p
        }()
        return HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 已理解並帶入下方欄位")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(parts.joined(separator: " · "))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            Spacer()
            Button(action: { resetModelDrivenAfterIntentEdit() }) {
                Text("重新輸入")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
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
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        baseStartDate = today
        baseEndDate = cal.date(byAdding: .day, value: 2, to: today) ?? today
        baseIsAllDay = false
        baseIsHasEnd = true
        taskDeadline = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        taskAvailableHoursPerDay = 4
        taskPriorityStrategy = "by_deadline"
        taskComplexity = "medium"
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
            let cal = Calendar.current
            let start = cal.startOfDay(for: Date())
            baseStartDate = start
            baseEndDate = cal.date(byAdding: .day, value: max(0, days - 1), to: start) ?? start
            baseIsAllDay = true
            baseIsHasEnd = true
            taskDeadline = cal.date(byAdding: .day, value: 7, to: Date()) ?? Date()
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
                // 修改內容：統一入口 — 選填欄位（描述、偏好、預算）收進「調整偏好」，已說過的內容不再要求掃整張表單
                DisclosureGroup(isExpanded: $showOptionalPreferences) {
                    VStack(spacing: 12) {
                        TextField("描述（選填）", text: $baseDescription, axis: .vertical)
                            .lineLimit(3...6)
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
                        // 修改内容：多階段型欄位（目的地/日期）與基礎資訊重複，已合併於上方；僅預算屬專屬欄位，直接併入基礎資訊
                        if plannerModelType == .multiPhase {
                            budgetField
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("調整偏好（選填）")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    /// 下段：依 plannerModelType 顯示模型專屬欄位
    /// 修改内容：多階段型不再有專屬區（欄位與基礎資訊重複，已合併），僅任務/協調等顯示專屬欄位
    @ViewBuilder
    private var modelSpecificFormSection: some View {
        if plannerModelType != .multiPhase {
            VStack(alignment: .leading, spacing: 16) {
                Text(modelSpecificSectionTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                switch plannerModelType {
                case .multiPhase:
                    EmptyView()
                case .floatingTask:
                    taskBreakdownFields
                case .availabilityCoordination:
                    availabilityCoordinationSection // 修改内容
                case .availability, .recurring, .matching, .aiOptimization:
                    timePlanningPlaceholderView
                }
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
        slots.durationDays = SlotInfo(value: modelDrivenTripDayCount, confidence: 1.0)
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
            departureDateTime: nil,
            adults: 1,
            children: 0,
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
    
    // 修改内容：与 AITripGenerator 内建列表同一数据源，避免重复建模
    
    // 修改内容：未手动选择时自动匹配默认主题
    private func inferDefaultTravelThemeId() -> String {
        AITripGenerator.inferTravelThemeModuleId(
            children: 0,
            combinedUserText: "\(tripTheme) \(additionalRequirements)",
            interestTagRawValues: selectedInterests.map { $0.rawValue }
        )
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
            presetBanner  // 修改內容：常用安排
            
            // 固定：計劃開始日期（僅當 formQuestions 未包含 plan_start_date/start_date 時顯示）
            if showFixedPlanDate {
                StandardFormUnit(title: "ai_planner.plan_start_date".localized()) {  // 修改内容：Step4 UX — 統一 StandardFormUnit
                    DatePicker("", selection: $themeFormStartDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // 固定：計劃時長（僅當 formQuestions 未包含 duration 相關問題時顯示）
            if showFixedPlanDuration {
                StandardFormUnit(title: "ai_planner.plan_duration".localized()) {  // 修改内容：Step4 UX — 統一 StandardFormUnit
                    HStack(spacing: 14) {
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
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
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
        StandardFormUnit(title: labelText, subtitle: question.description) {  // 修改内容：Step4 UX — 統一 StandardFormUnit
            switch question.type {
            case .text:
                TextField(placeholderText, text: Binding(
                    get: { themeFormAnswers[question.id] ?? question.defaultValue ?? "" },
                    set: { updateThemeFormAnswer(question.id, value: $0) }
                ))
                .textFieldStyle(.plain)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(UIColor.systemGray4).opacity(0.6), lineWidth: 1)
                )
                
            case .number:
                let minV = question.minValue ?? 0
                let maxV = question.maxValue ?? 999
                let binding = Binding(
                    get: { Int(themeFormAnswers[question.id] ?? question.defaultValue ?? "\(minV)") ?? minV },
                    set: { updateThemeFormAnswer(question.id, value: "\($0)") }
                )
                HStack(spacing: 14) {
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
                        .frame(minWidth: 80, alignment: .leading)
                    Button(action: {
                        let v = binding.wrappedValue
                        if v < maxV { binding.wrappedValue = v + 1 }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(binding.wrappedValue < maxV ? .blue : .gray)
                    }
                    .disabled(binding.wrappedValue >= maxV)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                
            case .select:
                if let options = question.options {
                    Picker("", selection: Binding(
                        get: { themeFormAnswers[question.id] ?? question.defaultValue ?? "" },
                        set: { updateThemeFormAnswer(question.id, value: $0) }
                    )) {
                        Text("--").tag("")
                        ForEach(options, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(UIColor.systemGray4).opacity(0.6), lineWidth: 1)
                    )
                } else {
                    Text("--")
                        .foregroundColor(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(14)
                }
                
            case .multiSelect:
                if let options = question.options {
                    let selected = Set((themeFormAnswers[question.id] ?? "")
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    )
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(options, id: \.self) { opt in
                            let isSelected = selected.contains(opt)
                            Button(action: {
                                var s = selected
                                if s.contains(opt) { s.remove(opt) } else { s.insert(opt) }
                                updateThemeFormAnswer(question.id, value: s.sorted().joined(separator: ", "))
                            }) {
                                HStack(spacing: 8) {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(Color(UIColor.systemGray3))
                                    }
                                    Text(opt)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .background(isSelected ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("--")
                        .foregroundColor(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(14)
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
                DatePicker("", selection: binding, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(UIColor.systemGray4).opacity(0.6), lineWidth: 1)
                    )

            // 修改内容：Step1 — 新增 location / time / toggle 三型渲染
            case .location:
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.blue)
                    TextField(placeholderText.isEmpty ? "location".localized() : placeholderText, text: Binding(
                        get: { themeFormAnswers[question.id] ?? question.defaultValue ?? "" },
                        set: { updateThemeFormAnswer(question.id, value: $0) }
                    ))
                    .textFieldStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(UIColor.systemGray4).opacity(0.6), lineWidth: 1)
                )

            case .time:
                let timeFormatter: DateFormatter = {
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm"
                    return f
                }()
                let binding = Binding(
                    get: {
                        let s = themeFormAnswers[question.id] ?? question.defaultValue
                        return s.flatMap { timeFormatter.date(from: $0) } ?? Date()
                    },
                    set: {
                        updateThemeFormAnswer(question.id, value: timeFormatter.string(from: $0))
                    }
                )
                DatePicker("", selection: binding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(UIColor.systemGray4).opacity(0.6), lineWidth: 1)
                    )

            case .toggle:
                Toggle(isOn: Binding(
                    get: { (themeFormAnswers[question.id] ?? question.defaultValue ?? "false") == "true" },
                    set: { updateThemeFormAnswer(question.id, value: $0 ? "true" : "false") }
                )) {
                    Text(placeholderText.isEmpty ? labelText : placeholderText)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
            }
        }
    }

    
    // MARK: - 步骤1：基本信息
    
    /// 步驟一：出發位置與住宿（行程基礎）
    
    // MARK: - 步骤2：偏好设置
    
    
    // MARK: - 步骤3：行程細節優化
    
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
            }
            // 修改内容：Step2 — step2/step3 按鈕已隨 travel 流程移至 TravelPlannerContent
        }
        .padding()
                .background(Color(UIColor.systemBackground))
    }
    
    private var canProceedToStep2: Bool {
        if useThemeFormMode {
            return themeFormResolvedDurationDays > 0
        }
        let cal = Calendar.current
        let s = cal.startOfDay(for: tripRangeStartDate)
        let e = cal.startOfDay(for: tripRangeEndDate)
        return !destination.isEmpty && e >= s && computedTripDayCount >= 1
    }
    
    
    private var supplementThemeTagsForGeneration: [String] {
        selectedSupplementKinds.sorted { $0.rawValue < $1.rawValue }.compactMap { k -> String? in
            if k == .other {
                let n = supplementOtherNote.trimmingCharacters(in: .whitespacesAndNewlines)
                return n.isEmpty ? nil : "補充主題·其他：\(n)"
            }
            return "補充主題·\(k.promptLabelZh())"
        }
    }
    
    
    
    /// 興趣偏好補充：依主題再載入一批周邊推薦地點

    
    
    
    
    
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
    
    
    // MARK: - 国家名称转换（英文转中文）
    
    // MARK: - 构建GPS定位显示文本（名字+地址）
    
    // 从历史记录中查找完整的目的地字符串（用于城市名匹配）
    
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
    
    // MARK: - 导航方法
    
    /// 離開步驟二前：若勾選「其他」但未填寫說明，視為未使用並清空狀態，避免擋住下一步。
    
    // 修改内容：Step2 — travel 四步驟已移至 TravelPlannerContent，此處僅剩：表單（step1）→ 生成（step4）
    private func goToNextStep() {
        withAnimation {
            switch currentStep {
            case .step1:
                currentStep = .step4
                startGeneration()
            default:
                break
            }
        }
    }
    
    private func goToPreviousStep() {
        withAnimation {
            switch currentStep {
            case .step4:
                currentStep = .step1
            default:
                break
            }
        }
    }
    
    // MARK: - AI生成
    
    // 修改内容：Step2 — 僅主題表單模式（travel 流程守衛移至 TravelPlannerContent）
    private func startGeneration() {
        guard themeFormResolvedDurationDays > 0 else { return }

        // 修改内容：Step3 — 主題分流改依 ThemeOutputContract：itinerary/taskList 放行，其餘提示即將支援
        if let theme = customTheme {
            let contract = ThemeOutputContract.from(themeMode: theme.themeMode)
            guard contract.isSupported else {
                errorMessage = "此主題型態即將支援"
                showErrorAlert = true
                return
            }
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
        
        // 初始化任务列表（主題表單模式文案）
        let destText = customTheme?.title ?? "計劃"
        pendingTasks = [
            "正在分析\(destText)需求",
            "正在規劃時間安排",
            "正在優化分配",
            "正在生成完整計劃"
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
            let sDay = calendar.startOfDay(for: startDate)
            let eDay = calendar.startOfDay(for: endDate)
            let tfDays = max(1, (calendar.dateComponents([.day], from: sDay, to: eDay).day ?? 0) + 1)
            slots.durationDays = SlotInfo(value: tfDays, confidence: 1.0)
            slots.interestTags = []
            slots.budgetLevel = SlotInfo(value: budgetLevel, confidence: 1.0)
        } else {
            let dayCount = computedTripDayCount
            let firstDay = calendar.startOfDay(for: tripRangeStartDate)
            let lastDay = calendar.startOfDay(for: tripRangeEndDate)
            startDate = combine(date: firstDay, time: departureTripStartTime)
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: lastDay) ?? lastDay
            dest = destination
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
        }
        
        let themeKeyForRequest = customTheme != nil ? "custom_\(customTheme!.key)" : "travel_planning"
        // 修改内容：若未手动选择则自动套用默认主题
        let resolvedTravelThemeId = selectedTravelThemeModuleId ?? inferDefaultTravelThemeId()
        let customInstructionsForRequest: String? = {
            var s = customTheme?.aiInstruction ?? ""
            if useThemeFormMode, let npi = buildAndValidateNPI().npi {
                let npiJson = NPIMapper.npiToPromptJSON(npi)
                s = (s.isEmpty ? "" : s + "\n\n") + "【標準輸入 NPI】\n\(npiJson)"
            }
            // 修改内容：行程主題／備註併入，與 inferTravelThemeModuleId、resolveTravelTheme 使用同一文本來源
            let parts = [tripTheme, additionalRequirements].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let hints = parts.joined(separator: "\n")
            if !hints.isEmpty {
                s = s.isEmpty ? hints : s + "\n\n" + hints
            }
            return s.isEmpty ? nil : s
        }()
        let modelType: PlannerModelType = .multiPhase
        let itineraryDayCount: Int = {
            let sDay = calendar.startOfDay(for: startDate)
            let eDay = calendar.startOfDay(for: endDate)
            return max(1, (calendar.dateComponents([.day], from: sDay, to: eDay).day ?? 0) + 1)
        }()
        let departureDT: Date? = useThemeFormMode ? nil : combine(date: Calendar.current.startOfDay(for: tripRangeStartDate), time: departureTripStartTime)
        // 修改内容：Step3 — floatingTasks 主題走任務拆解：模型/模式/標題/描述/參數對應帶入
        let isTaskTheme = customTheme?.themeMode == .floatingTasks
        let taskThemeDescription: String? = {
            guard isTaskTheme, let theme = customTheme else { return nil }
            let summary = ThemeTemplate.from(theme: theme, builtInBase: nil)
                .freeformAnswersSummary(answers: themeFormAnswers)
            let parts = [theme.aiInstruction, summary].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        }()
        let request = GenerateRequest(
            plannerModelType: isTaskTheme ? .floatingTask : modelType,
            generateMode: isTaskTheme ? .taskBreakdown : (itineraryDayCount == 1 ? .singleDay : .multiDay),
            themeKey: themeKeyForRequest,
            themeMode: customTheme?.themeMode ?? .generateItinerary,
            userId: userManager.userOpenId.isEmpty ? nil : userManager.userOpenId,
            title: isTaskTheme ? customTheme?.title : nil,
            description: taskThemeDescription,
            startDate: isTaskTheme ? startDate : nil,
            endDate: isTaskTheme ? endDate : nil,
            slots: slots,
            assumptions: [],
            riskFlags: [],
            npi: useThemeFormMode ? buildAndValidateNPI().npi : nil,
            customInstructions: customInstructionsForRequest,
            departureLocation: useCustomDepartureLocation ? (customDepartureCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }) : currentGPSLocation,
            accommodationAddress: accommodationAddress.isEmpty ? nil : accommodationAddress,
            accommodationCoordinate: accommodationCoordinate,
            selectedAttractionNames: surroundingAttractions.filter { selectedSurroundingAttractions.contains($0.id) }.map { $0.name },
            customSurroundingTags: useThemeFormMode ? [] : supplementThemeTagsForGeneration,
            departureDateTime: departureDT,
            adults: 1,
            children: 0,
            planningDomain: isTaskTheme ? .task : .travel,
            planningIntensity: nil,
            travelThemeModuleId: isTaskTheme ? nil : resolvedTravelThemeId,
            taskBreakdown: isTaskTheme ? TaskBreakdownParams(
                deadline: endDate,
                availableHoursPerDay: nil,
                priorityStrategy: nil,
                taskComplexity: nil
            ) : nil
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
