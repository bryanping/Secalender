//
//  QuickThemeManager.swift
//  Secalender
//
//  快速主題管理器：管理內建與自定義主題，支援排序、搜索、收藏
//

import Foundation
import SwiftUI

// MARK: - 主題模式（決定 AI 流程分流）
enum ThemeMode: String, Codable, CaseIterable {
    case generateItinerary = "generateItinerary"   // 生成行程（走 AITripGenerator）
    case floatingTasks = "floatingTasks"           // 浮動任務（不生成景點，生成任務清單）
    case collectAvailability = "collectAvailability" // 收集可用時間
    case collectInfoOnly = "collectInfoOnly"       // 只收集資訊
    case matchingSchedule = "matchingSchedule"     // 撮合排程
    case resourceBooking = "resourceBooking"       // 資源預約
    
    var displayName: String {
        switch self {
        case .generateItinerary: return "generateItinerary"
        case .floatingTasks: return "floatingTasks"
        case .collectAvailability: return "collectAvailability"
        case .collectInfoOnly: return "collectInfoOnly"
        case .matchingSchedule: return "matchingSchedule"
        case .resourceBooking: return "resourceBooking"
        }
    }
}

// MARK: - 快速主題分類
enum QuickThemeCategory: String, CaseIterable {
    case all = "all"
    case popular = "popular"
    case custom = "custom"
    case favorites = "favorites"
    
    var localizedKey: String {
        switch self {
        case .all: return "quick_theme.category.all"
        case .popular: return "quick_theme.category.popular"
        case .custom: return "quick_theme.category.custom"
        case .favorites: return "quick_theme.category.favorites"
        }
    }
}

// MARK: - 主題表單問題類型
enum ThemeFormQuestionType: String, Codable {
    case text
    case number
    case select
    case multiSelect
    case date
}

/// 主題專屬提示詞與表單配置（未來可存 Firestore 分享）
struct ThemePromptConfig: Codable, Equatable {
    let themeKey: String
    var welcomeTitleKey: String
    var welcomeSubtitleKey: String
    var formQuestions: [ThemeFormQuestion]?
    var aiPromptBase: String?
    var requiresAI: Bool
}

/// 表單保留欄位 ID：當 formQuestions 包含這些 id 時，不顯示固定的「計劃開始日期／計劃時長」區塊
/// - plan_start_date / start_date (type: date) → 取代固定日期選擇器
/// - plan_duration_days / duration_days / plan_duration_weeks / duration_weeks (type: number) → 取代固定天數 stepper
enum ThemeFormReservedId {
    static let dateIds = ["plan_start_date", "start_date"]
    static let durationDayIds = ["plan_duration_days", "duration_days"]
    static let durationWeekIds = ["plan_duration_weeks", "duration_weeks"]
    
    static func hasDateQuestion(in questions: [ThemeFormQuestion]) -> Bool {
        questions.contains { q in dateIds.contains(q.id) && q.type == .date }
    }
    
    static func hasDurationQuestion(in questions: [ThemeFormQuestion]) -> Bool {
        questions.contains { q in
            (durationDayIds.contains(q.id) || durationWeekIds.contains(q.id)) && q.type == .number
        }
    }
}

/// 主題專屬表單問題：由 AI 根據主題內容生成，用於 AIPlannerView 動態收集所需資訊
struct ThemeFormQuestion: Identifiable, Codable, Equatable {
    let id: String
    var label: String
    let type: ThemeFormQuestionType
    var options: [String]?  // select / multiSelect 選項
    var unit: String?       // 單位，如 "週"、"分鐘"
    var placeholder: String?
    var defaultValue: String?
    var minValue: Int?
    var maxValue: Int?
    var description: String?  // 說明，可編輯後用於 AI 生成新選項
}

// MARK: - 快速主題（支援自定義）
struct QuickTheme: Identifiable, Equatable, Codable {
    enum CodingKeys: String, CodingKey {
        case id, key, icon, iconColorHex, title, aiPromptPrefix, themeMode, aiInstruction, advancedParams, formQuestions, sortOrder, isFavorite, isBuiltIn
    }
    var id: UUID
    let key: String  // 路由識別：weekend_flash, deep_culture, enrich_trip, travel_planning, 或 custom_xxx
    var icon: String
    var iconColorHex: String  // 儲存為 hex 以便 Codable
    var title: String
    /// 主題專屬提示詞：約束 AI 生成符合主題的行程（如寵物餵養→寵物餐廳/公園，禁止無關景點）。存 Firebase 可遠端更新。
    var aiPromptPrefix: String?
    /// 主題用途：決定是否走 itinerary 生成器。非 generateItinerary 不呼叫 AITripGenerator。
    var themeMode: ThemeMode
    var aiInstruction: String?  // 自定義 AI 指令
    var advancedParams: String?  // 進階參數（由 AI 補全）
    var formQuestions: [ThemeFormQuestion]?  // 主題專屬表單問題（由 AI 生成）
    var sortOrder: Int
    var isFavorite: Bool
    let isBuiltIn: Bool  // 內建主題不可刪除
    
    var iconColor: Color {
        Self.colorFromHex(iconColorHex) ?? .blue
    }
    
    private static func colorFromHex(_ hex: String) -> Color? {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
    
    init(
        id: UUID = UUID(),
        key: String,
        icon: String,
        iconColorHex: String,
        title: String,
        aiPromptPrefix: String? = nil,
        themeMode: ThemeMode = .generateItinerary,
        aiInstruction: String? = nil,
        advancedParams: String? = nil,
        formQuestions: [ThemeFormQuestion]? = nil,
        sortOrder: Int = 0,
        isFavorite: Bool = false,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.key = key
        self.icon = icon
        self.iconColorHex = iconColorHex
        self.title = title
        self.aiPromptPrefix = aiPromptPrefix
        self.themeMode = themeMode
        self.aiInstruction = aiInstruction
        self.advancedParams = advancedParams
        self.formQuestions = formQuestions
        self.sortOrder = sortOrder
        self.isFavorite = isFavorite
        self.isBuiltIn = isBuiltIn
    }
    
    static func builtIn(key: String, icon: String, iconColorHex: String, title: String, themeMode: ThemeMode = .generateItinerary) -> QuickTheme {
        QuickTheme(key: key, icon: icon, iconColorHex: iconColorHex, title: title, themeMode: themeMode, sortOrder: 0, isBuiltIn: true)
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        key = try c.decode(String.self, forKey: .key)
        icon = try c.decode(String.self, forKey: .icon)
        iconColorHex = try c.decode(String.self, forKey: .iconColorHex)
        title = try c.decode(String.self, forKey: .title)
        aiPromptPrefix = try c.decodeIfPresent(String.self, forKey: .aiPromptPrefix)
        themeMode = (try? c.decode(ThemeMode.self, forKey: .themeMode)) ?? .generateItinerary
        aiInstruction = try c.decodeIfPresent(String.self, forKey: .aiInstruction)
        advancedParams = try c.decodeIfPresent(String.self, forKey: .advancedParams)
        formQuestions = try c.decodeIfPresent([ThemeFormQuestion].self, forKey: .formQuestions)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        isFavorite = try c.decode(Bool.self, forKey: .isFavorite)
        isBuiltIn = try c.decode(Bool.self, forKey: .isBuiltIn)
    }
}

// MARK: - 內建主題專屬問題集（還原週末快閃／深度文化／充實行程）
extension QuickThemeManager {
    /// 週末快閃：交通 1 小時內、逛街生活景點、可選主題後生周邊特色
    static func weekendFlashFormQuestions() -> [ThemeFormQuestion] {
        [
            ThemeFormQuestion(id: "start_date", label: "weekend_flash.form.start_date", type: .date, options: nil, unit: nil, placeholder: nil, defaultValue: nil, minValue: nil, maxValue: nil, description: "計劃日期"),
            ThemeFormQuestion(id: "duration_days", label: "weekend_flash.form.duration_days", type: .number, options: nil, unit: "天", placeholder: nil, defaultValue: "1", minValue: 1, maxValue: 1, description: "固定 1 天"),
            ThemeFormQuestion(id: "destination", label: "weekend_flash.form.destination", type: .text, options: nil, unit: nil, placeholder: "weekend_flash.form.destination_placeholder", defaultValue: nil, minValue: nil, maxValue: nil, description: "地點（城市或區域）"),
            ThemeFormQuestion(id: "travel_limit_minutes", label: "weekend_flash.form.travel_limit", type: .number, options: nil, unit: "分鐘", placeholder: nil, defaultValue: "60", minValue: 30, maxValue: 120, description: "交通時間上限"),
            ThemeFormQuestion(id: "theme_type", label: "weekend_flash.form.theme_type", type: .multiSelect, options: ["逛街", "生活景點", "咖啡輕食", "文創市集", "自然風光", "美食街區", "藝術空間"], unit: nil, placeholder: nil, defaultValue: nil, minValue: nil, maxValue: nil, description: "主題（選後生周邊特色）")
        ]
    }
    
    /// 深度文化：當前城市、古蹟／古城／美術／展覽等
    static func deepCultureFormQuestions() -> [ThemeFormQuestion] {
        [
            ThemeFormQuestion(id: "start_date", label: "deep_culture.form.start_date", type: .date, options: nil, unit: nil, placeholder: nil, defaultValue: nil, minValue: nil, maxValue: nil, description: "計劃開始日期"),
            ThemeFormQuestion(id: "duration_days", label: "deep_culture.form.duration_days", type: .number, options: nil, unit: "天", placeholder: nil, defaultValue: "1", minValue: 1, maxValue: 14, description: "天數"),
            ThemeFormQuestion(id: "city", label: "deep_culture.form.city", type: .text, options: nil, unit: nil, placeholder: "deep_culture.form.city_placeholder", defaultValue: nil, minValue: nil, maxValue: nil, description: "當前／目標城市"),
            ThemeFormQuestion(id: "culture_type", label: "deep_culture.form.culture_type", type: .multiSelect, options: ["古蹟", "古城", "美術館", "博物館", "短期展覽", "歷史建築", "文化活動"], unit: nil, placeholder: nil, defaultValue: nil, minValue: nil, maxValue: nil, description: "類型")
        ]
    }
    
    /// 充實行程：行程目標、周圍推薦（購物／美食／休憩等）
    static func enrichTripFormQuestions() -> [ThemeFormQuestion] {
        [
            ThemeFormQuestion(id: "start_date", label: "enrich_trip.form.start_date", type: .date, options: nil, unit: nil, placeholder: nil, defaultValue: nil, minValue: nil, maxValue: nil, description: "計劃開始日期"),
            ThemeFormQuestion(id: "duration_days", label: "enrich_trip.form.duration_days", type: .number, options: nil, unit: "天", placeholder: nil, defaultValue: "3", minValue: 1, maxValue: 30, description: "天數"),
            ThemeFormQuestion(id: "trip_goal", label: "enrich_trip.form.trip_goal", type: .text, options: nil, unit: nil, placeholder: "enrich_trip.form.trip_goal_placeholder", defaultValue: nil, minValue: nil, maxValue: nil, description: "行程目標或目的地"),
            ThemeFormQuestion(id: "surrounding_categories", label: "enrich_trip.form.surrounding", type: .multiSelect, options: ["購物", "美食", "休憩", "景點", "夜生活", "親子"], unit: nil, placeholder: nil, defaultValue: nil, minValue: nil, maxValue: nil, description: "周圍推薦類型")
        ]
    }
}

// MARK: - QuickThemeManager
@MainActor
final class QuickThemeManager: ObservableObject {
    static let shared = QuickThemeManager()
    private let userDefaults = UserDefaults.standard
    private let customThemesKey = "quick_theme_custom_themes"
    private let sortOrderKey = "quick_theme_sort_order"
    
    // 內建主題（預設）
    private let builtInThemes: [QuickTheme] = [
        .builtIn(key: "weekend_flash", icon: "bolt.fill", iconColorHex: "#FF9500", title: "weekend_flash.template_name"),
        .builtIn(key: "deep_culture", icon: "building.columns.fill", iconColorHex: "#AF52DE", title: "deep_culture.template_name"),
        .builtIn(key: "enrich_trip", icon: "fork.knife", iconColorHex: "#34C759", title: "enrich_trip.template_name"),
        .builtIn(key: "travel_planning", icon: "map.fill", iconColorHex: "#007AFF", title: "travel_planning.template_name")
    ]
    
    /// 內建主題專屬提示詞與問題集（還原週末快閃／深度文化／充實行程各自問題集）
    private let builtInPromptConfigs: [String: ThemePromptConfig] = [
        "weekend_flash": ThemePromptConfig(
            themeKey: "weekend_flash",
            welcomeTitleKey: "weekend_flash.welcome_title",
            welcomeSubtitleKey: "weekend_flash.welcome_subtitle",
            formQuestions: QuickThemeManager.weekendFlashFormQuestions(),
            aiPromptBase: "【週末快閃】僅推薦交通 1 小時內可達的逛街、生活、景點；依使用者選擇的主題（逛街／生活景點／咖啡輕食／文創市集／自然風光等）產出周邊特色，安排緊湊一日遊。",
            requiresAI: true
        ),
        "deep_culture": ThemePromptConfig(
            themeKey: "deep_culture",
            welcomeTitleKey: "deep_culture.welcome_title",
            welcomeSubtitleKey: "deep_culture.welcome_subtitle",
            formQuestions: QuickThemeManager.deepCultureFormQuestions(),
            aiPromptBase: "【深度文化】搜尋並推薦當前城市的古蹟、古城、美術館、博物館、歷史建築、文化活動，以及短期美術／藝術展覽；以文化與藝術體驗為主安排行程。",
            requiresAI: true
        ),
        "enrich_trip": ThemePromptConfig(
            themeKey: "enrich_trip",
            welcomeTitleKey: "enrich_trip.welcome_title",
            welcomeSubtitleKey: "enrich_trip.welcome_subtitle",
            formQuestions: QuickThemeManager.enrichTripFormQuestions(),
            aiPromptBase: "【充實行程】依使用者填寫的行程目標或目的地，推薦目標周圍的購物、美食、休憩、景點、夜生活、親子等選項，補齊並充實既有行程。",
            requiresAI: true
        ),
        "travel_planning": ThemePromptConfig(
            themeKey: "travel_planning",
            welcomeTitleKey: "travel_planning.welcome_title",
            welcomeSubtitleKey: "travel_planning.welcome_subtitle",
            formQuestions: nil,
            aiPromptBase: nil,
            requiresAI: true
        )
    ]
    
    @Published private(set) var customThemes: [QuickTheme] = []
    
    private init() {
        loadCustomThemes()
    }
    
    private static func localizedString(_ key: String) -> String {
        let code = UserDefaults.standard.string(forKey: "app_language") ?? ""
        let bundle: Bundle
        if code.isEmpty {
            bundle = .main
        } else if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
                  let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = .main
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    // MARK: - 取得所有主題（含內建 + 自定義，已排序；內建會帶入專屬 formQuestions 與 aiInstruction）
    func allThemes(userId: String = "") -> [QuickTheme] {
        let custom = loadCustomThemesForUser(userId)
        var combined = builtInThemes.map { theme in
            let config = builtInPromptConfigs[theme.key]
            return QuickTheme(
                id: theme.id,
                key: theme.key,
                icon: theme.icon,
                iconColorHex: theme.iconColorHex,
                title: Self.localizedString(theme.title),
                aiPromptPrefix: theme.aiPromptPrefix,
                themeMode: theme.themeMode,
                aiInstruction: config?.aiPromptBase ?? theme.aiInstruction,
                advancedParams: theme.advancedParams,
                formQuestions: config?.formQuestions ?? theme.formQuestions,
                sortOrder: theme.sortOrder,
                isFavorite: theme.isFavorite,
                isBuiltIn: true
            )
        }
        combined.append(contentsOf: custom.map { t in
            var t2 = t
            if t.title.hasPrefix("quick_theme.") || t.title.hasPrefix("weekend_flash.") || t.title.hasPrefix("deep_culture.") || t.title.hasPrefix("enrich_trip.") || t.title.hasPrefix("travel_planning.") {
                t2.title = Self.localizedString(t.title)
            }
            return t2
        })
        return combined.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // MARK: - 篩選
    func themes(for category: QuickThemeCategory, searchText: String = "", userId: String = "") -> [QuickTheme] {
        var list = allThemes(userId: userId)
        
        switch category {
        case .all:
            break
        case .popular:
            // 熱門：內建主題
            list = list.filter { $0.isBuiltIn }
        case .custom:
            list = list.filter { !$0.isBuiltIn }
        case .favorites:
            list = list.filter { $0.isFavorite }
        }
        
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.title.lowercased().contains(q) ||
                ($0.aiInstruction?.lowercased().contains(q) ?? false)
            }
        }
        
        return list
    }
    
    // MARK: - 自定義主題 CRUD
    func addCustomTheme(_ theme: QuickTheme, userId: String = "") {
        var themes = loadCustomThemesForUser(userId)
        var t = theme
        t.sortOrder = (themes.map(\.sortOrder).max() ?? -1) + 1
        themes.append(t)
        saveCustomThemes(themes, userId: userId)
        objectWillChange.send()
        ActivityRecorder.recordThemeCreated(title: t.title, themeId: t.id.uuidString)
    }
    
    func updateCustomTheme(_ theme: QuickTheme, userId: String = "") {
        var themes = loadCustomThemesForUser(userId)
        if let i = themes.firstIndex(where: { $0.id == theme.id }) {
            themes[i] = theme
            saveCustomThemes(themes, userId: userId)
            objectWillChange.send()
        }
    }
    
    func deleteCustomTheme(id: UUID, userId: String = "") {
        var themes = loadCustomThemesForUser(userId)
        guard let removed = themes.first(where: { $0.id == id }) else { return }
        themes.removeAll { $0.id == id }
        saveCustomThemes(themes, userId: userId)
        objectWillChange.send()
        // 同步刪除 Firebase 中的主題提示詞
        Task {
            await ThemePromptService.shared.deletePrompt(themeKey: removed.key, userId: userId)
        }
    }
    
    func toggleFavorite(themeId: UUID, userId: String = "") {
        var themes = loadCustomThemesForUser(userId)
        if let i = themes.firstIndex(where: { $0.id == themeId }) {
            themes[i].isFavorite.toggle()
            saveCustomThemes(themes, userId: userId)
            objectWillChange.send()
        }
    }
    
    func updateSortOrder(themes: [QuickTheme], userId: String = "") {
        var custom = loadCustomThemesForUser(userId)
        for (idx, t) in themes.enumerated() where !t.isBuiltIn {
            if let i = custom.firstIndex(where: { $0.id == t.id }) {
                custom[i].sortOrder = idx
            }
        }
        saveCustomThemes(custom, userId: userId)
        objectWillChange.send()
    }
    
    // MARK: - 主題專屬提示詞與表單
    
    /// 取得主題的提示詞配置（內建從 config，自訂從 theme 的 formQuestions）
    func promptConfig(for themeKey: String) -> ThemePromptConfig? {
        builtInPromptConfigs[themeKey]
    }
    
    /// 取得主題專屬歡迎標題（用於 AIPlannerView 等）
    /// - Parameter theme: nil 時視為 travel_planning（TravelPlanningView）
    func welcomeTitle(for theme: QuickTheme?) -> String {
        if let theme = theme {
            if theme.isBuiltIn, let config = builtInPromptConfigs[theme.key] {
                return Self.localizedString(config.welcomeTitleKey)
            }
            if theme.formQuestions != nil, !(theme.formQuestions?.isEmpty ?? true) {
                return Self.localizedString("custom_theme.welcome_title").replacingOccurrences(of: "%@", with: theme.title)
            }
            return theme.title
        }
        // 無 customTheme = TravelPlanningView，使用 travel_planning 配置
        if let config = builtInPromptConfigs["travel_planning"] {
            return Self.localizedString(config.welcomeTitleKey)
        }
        return Self.localizedString("ai_planner.tell_us_your_plan")
    }
    
    /// 取得主題專屬歡迎副標題
    func welcomeSubtitle(for theme: QuickTheme?) -> String {
        if let theme = theme {
            if theme.isBuiltIn, let config = builtInPromptConfigs[theme.key] {
                return Self.localizedString(config.welcomeSubtitleKey)
            }
            return Self.localizedString("ai_planner.theme_form_subtitle")
        }
        if let config = builtInPromptConfigs["travel_planning"] {
            return Self.localizedString(config.welcomeSubtitleKey)
        }
        return Self.localizedString("ai_planner.start_with_basics")
    }
    
    // MARK: - 持久化
    private func loadCustomThemes() {
        let key = "\(customThemesKey)_default"
        guard let data = userDefaults.data(forKey: key) else { return }
        if let decoded = try? JSONDecoder().decode([QuickTheme].self, from: data) {
            customThemes = decoded
        }
    }
    
    private func loadCustomThemesForUser(_ userId: String) -> [QuickTheme] {
        let key = "\(customThemesKey)_\(userId.isEmpty ? "default" : userId)"
        guard let data = userDefaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([QuickTheme].self, from: data)) ?? []
    }
    
    private func saveCustomThemes(_ themes: [QuickTheme], userId: String = "") {
        let key = "\(customThemesKey)_\(userId.isEmpty ? "default" : userId)"
        if let encoded = try? JSONEncoder().encode(themes) {
            userDefaults.set(encoded, forKey: key)
        }
    }
}
