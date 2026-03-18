//
//  ThemeResolver.swift
//  Secalender
//
//  主題解析：決定是否允許 itinerary、取得 promptSet / 主題前綴。
//  對應架構：ThemePromptService（theme_prompts）＋ QuickThemeManager（themeMode）。
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

    /// 解析請求中的主題（非同步）：若提供 userId 則從 ThemePromptService 讀取 promptPrefix，否則用內建
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
