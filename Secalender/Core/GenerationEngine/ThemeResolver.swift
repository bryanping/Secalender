//
//  ThemeResolver.swift
//  Secalender
//
//  主題解析：決定是否允許 itinerary、取得 promptSet / 主題前綴。
//  對應架構：ThemePromptService（theme_prompts）＋ QuickThemeManager（themeMode）。
//
//  修改内容：兩套「主題」分層（勿刪其一、勿混用欄位）
//  - Firebase / QuickTheme（themeKey + ThemePromptService）提供「通用」行程 promptPrefix（品牌/場景約束）。
//  - TravelThemeModule（GenerateRequest.travelThemeModuleId）是 **travel itinerary 專用** 的結構化控制層（密度、偏好、避免模式、promptPrefix 中的行程策略）。
//  兩者為 **疊加關係**，不互相替代；TravelThemeModule 的硬約束（見 AITripGenerator.mandatoryTravelConstraintsFooter）不得被遠端 prompt 覆蓋。
//  - themeKey：QuickTheme / weekend_flash / travel_planning 等路由鍵
//  - travelThemeModuleId：family_relaxed / slow_city_walk / food_explore / efficient_highlights 等內建模組 id
//
//  ── 功能驗收清單（手動跑 App，勿盲改）──
//  A 手選四主題各生成一次：travelThemeModuleId 變化、resolveTravelTheme 讀到對應 id、prompt 含對應 promptPrefix、輸出風格差異。
//  B 未選主題自動推断（將文案放在行程主題或備註）：「東京三天親子輕鬆」→ family_relaxed；「京都慢游散步咖啡書店」→ slow_city_walk；「大阪美食之旅」→ food_explore；「東京三天重點景點打卡」→ efficient_highlights。
//  C 壓力輸入「越豐富越好」：仍應主線稀疏、optional/fallback 有內容，不回到塞滿式；否則檢查 mandatoryTravelConstraintsFooter 與拼接順序。
//  D TravelPlannerContent 第 4 步「已套用主題」須與 GenerateRequest.travelThemeModuleId / resolvedTravelThemeId 一致（同一套推断）。
//  E 高密輸入下 optionalActivities / fallbackActivities 是否非空（分配引擎須「降級」而非僅刪除）。
//

import Foundation

/// 主題解析結果
struct ThemeResolution {
    var allowsItinerary: Bool
    var themeKey: String
    var promptPrefix: String?
    var themeMode: ThemeMode
}

enum ThemeResolverError: LocalizedError {
    case itineraryNotAllowed(themeMode: ThemeMode)

    var errorDescription: String? {
        switch self {
        case .itineraryNotAllowed: return "此主題不支援行程生成"
        }
    }
}

final class ThemeResolver {
    static let shared = ThemeResolver()
    private init() {}

    /// 解析請求中的主題（非同步）：若提供 userId 則從 ThemePromptService 讀取 promptPrefix，否則用內建。
    /// 修改内容：此處只負責 QuickTheme/Firebase 的通用 prefix；**travel 專用策略** 由 `GenerateRequest.travelThemeModuleId` + `AITripGenerator` 處理（見檔案頂部說明）。
    func resolve(request: GenerateRequest) async throws -> ThemeResolution {
        let mode = request.themeMode
        let key = request.themeKey ?? "travel_planning"
        if mode != .generateItinerary {
            throw ThemeResolverError.itineraryNotAllowed(themeMode: mode)
        }
        var prefix: String? = nil
        if let uid = request.userId, !uid.isEmpty {
            prefix = await ThemePromptService.shared.fetchPrompt(themeKey: key, userId: uid)
        }
        return ThemeResolution(allowsItinerary: true, themeKey: key, promptPrefix: prefix, themeMode: mode)
    }
}
