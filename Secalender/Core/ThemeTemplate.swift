//
//  ThemeTemplate.swift
//  Secalender
//
//  修改内容：Step1 統一模板 Schema
//  收斂四層重疊概念為單一模板結構：
//  - QuickTheme.aiPromptPrefix / aiInstruction / ThemePromptConfig.aiPromptBase → promptLayers.base
//  - ThemePromptService（Firebase theme_prompts）→ promptLayers.user
//  - TravelThemeModule（GenerateRequest.travelThemeModuleId）→ promptLayers.travelModuleId（僅 travel domain）
//  拼接順序固定：base → user；travel 模組策略由 AITripGenerator 疊加（硬約束不得被覆蓋）。
//  outputContract 由 themeMode 推導，宣告「此模板生成什麼」，供 UI 與引擎分流。
//

import Foundation

// MARK: - 輸出契約：模板宣告生成結果型態
enum ThemeOutputContract: String, Codable {
    case itinerary              // 行程（含景點/餐廳，走 AITripGenerator）
    case taskList               // 任務清單（走 taskBreakdown，不生成景點）
    case availabilityCollection // 可用時間收集（Coordination）
    case infoCollection         // 純資訊收集，不排程
    case matching               // 撮合排程
    case booking                // 資源預約

    /// 由 ThemeMode 推導（單一真實來源，勿在他處重複 switch）
    static func from(themeMode: ThemeMode) -> ThemeOutputContract {
        switch themeMode {
        case .generateItinerary: return .itinerary
        case .floatingTasks: return .taskList
        case .collectAvailability: return .availabilityCollection
        case .collectInfoOnly: return .infoCollection
        case .matchingSchedule: return .matching
        case .resourceBooking: return .booking
        }
    }

    /// 現階段引擎是否已支援此契約（未支援者 UI 應隱藏/降級，而非報錯）
    var isSupported: Bool {
        switch self {
        case .itinerary, .taskList: return true
        case .availabilityCollection, .infoCollection, .matching, .booking: return false
        }
    }
}

// MARK: - 提示詞分層（疊加關係，不互相替代）
struct ThemePromptLayers: Codable, Equatable {
    /// 內建/模板基礎約束（品牌/場景），來源：ThemePromptConfig.aiPromptBase 或 QuickTheme.aiInstruction
    var base: String?
    /// 使用者自訂前綴（Firebase theme_prompts.promptPrefix，可遠端更新）
    var user: String?
    /// travel itinerary 專用結構化模組 id（family_relaxed 等），由 AITripGenerator 處理，硬約束不可覆蓋
    var travelModuleId: String?

    /// 固定拼接順序：base → user。空層自動略過。travel 層不在此拼接。
    var composedPrefix: String? {
        let parts = [base, user]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
}

// MARK: - 統一模板
struct ThemeTemplate: Codable, Equatable {
    let themeKey: String
    var themeMode: ThemeMode
    var outputContract: ThemeOutputContract
    var formQuestions: [ThemeFormQuestion]
    var promptLayers: ThemePromptLayers

    // MARK: 組裝（同步部分：不含 Firebase user 層）
    /// 由 QuickTheme 組裝；builtInBase 傳入 QuickThemeManager.promptConfig(for:)?.aiPromptBase
    static func from(theme: QuickTheme, builtInBase: String?) -> ThemeTemplate {
        ThemeTemplate(
            themeKey: theme.key,
            themeMode: theme.themeMode,
            outputContract: .from(themeMode: theme.themeMode),
            formQuestions: theme.formQuestions ?? [],
            promptLayers: ThemePromptLayers(
                base: builtInBase ?? theme.aiInstruction ?? theme.aiPromptPrefix,
                user: nil,
                travelModuleId: nil
            )
        )
    }

    /// 補上 Firebase user 層（非同步入口統一在此，勿在 View 各自 fetch）
    mutating func loadUserLayer(userId: String?) async {
        guard let uid = userId, !uid.isEmpty else { return }
        promptLayers.user = await ThemePromptService.shared.fetchPrompt(themeKey: themeKey, userId: uid)
    }

    // MARK: 表單答案 → 語意值（role 優先，id 回退；集中於 ThemeFormReservedId）
    func resolvedStartDate(answers: [String: String]) -> Date? {
        ThemeFormReservedId.resolveStartDate(questions: formQuestions, answers: answers)
    }

    func resolvedDurationDays(answers: [String: String]) -> Int? {
        ThemeFormReservedId.resolveDurationDays(questions: formQuestions, answers: answers)
    }

    func resolvedDestination(answers: [String: String]) -> String? {
        for q in formQuestions where q.role == .destination || q.type == .location {
            if let s = answers[q.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s }
        }
        return nil
    }

    /// 其餘非保留欄位 → 供 prompt 的「問題: 答案」摘要（保留欄位已由上方語意值消化，避免重複進 prompt）
    func freeformAnswersSummary(answers: [String: String]) -> String? {
        var lines: [String] = []
        for q in formQuestions {
            if ThemeFormReservedId.isDateQuestion(q) || ThemeFormReservedId.isDurationDayQuestion(q) || ThemeFormReservedId.isDurationWeekQuestion(q) { continue }
            guard let a = answers[q.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty else { continue }
            lines.append("\(q.label): \(a)")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

// MARK: - 解析入口（取代各頁自行拼 QuickTheme + ThemePromptService）
extension ThemeTemplate {
    /// 依 themeKey 解析完整模板（含 Firebase user 層）。找不到主題時回傳最小模板（travel_planning 慣例）。
    static func resolve(themeKey: String, userId: String?) async -> ThemeTemplate {
        let (theme, base) = await MainActor.run { () -> (QuickTheme?, String?) in
            let mgr = QuickThemeManager.shared
            let t = mgr.allThemes(userId: userId ?? "").first { $0.key == themeKey }
            return (t, mgr.promptConfig(for: themeKey)?.aiPromptBase)
        }
        var template: ThemeTemplate
        if let t = theme {
            template = .from(theme: t, builtInBase: base)
        } else {
            template = ThemeTemplate(
                themeKey: themeKey,
                themeMode: .generateItinerary,
                outputContract: .itinerary,
                formQuestions: [],
                promptLayers: ThemePromptLayers(base: base, user: nil, travelModuleId: nil)
            )
        }
        await template.loadUserLayer(userId: userId)
        return template
    }
}
