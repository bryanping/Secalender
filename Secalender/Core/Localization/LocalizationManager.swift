//
//  LocalizationManager.swift
//  Secalender
//
//  Created by Assistant on 2026/1/27.
//

import Foundation
import SwiftUI

// MARK: - 支持的语言代码
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = ""                  //修改内容：新增 system 作为“跟随系统”
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case japanese = "ja"

    var id: String { rawValue }

    var localizedDisplayNameKey: String { //修改内容：统一用 key
        switch self {
        case .system: return "settings.language_system"
        case .english: return "language.english"
        case .simplifiedChinese: return "language.simplified_chinese"
        case .traditionalChinese: return "language.traditional_chinese"
        case .german: return "language.german"
        case .french: return "language.french"
        case .spanish: return "language.spanish"
        case .japanese: return "language.japanese"
        }
    }
}

// MARK: - 本地化管理器（App内切换语言：稳定版）
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @AppStorage("app_language") private var storedLanguageCode: String = ""  //修改内容：改用 AppStorage

    @Published private(set) var localeIdentifier: String = Locale.autoupdatingCurrent.identifier //修改内容：autoupdating 更符合“跟随系统”
    @Published private(set) var bundle: Bundle = .main

    private init() {
        applyLanguage(code: storedLanguageCode)
    }

    // MARK: - Public
    var currentLanguage: AppLanguage {
        AppLanguage(rawValue: storedLanguageCode) ?? .system
    }

    func setLanguage(_ language: AppLanguage) {
        storedLanguageCode = language.rawValue
        applyLanguage(code: storedLanguageCode)
    }

    // MARK: - Internal
    private func applyLanguage(code: String) {
        //修改内容：system 使用 autoupdatingCurrent，指定语言则直接用语言码（en/zh-Hans/...）
        if code.isEmpty {
            localeIdentifier = Locale.autoupdatingCurrent.identifier
            bundle = .main
            return
        } else {
            localeIdentifier = code
        }

        //修改内容：指定 bundle（不动 AppleLanguages）
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = .main
        }
    }

    // MARK: - Localization
    func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    func localized(_ key: String, _ args: CVarArg...) -> String { //修改内容：支持可变参数
        let format = NSLocalizedString(key, bundle: bundle, comment: "")
        return String(format: format, locale: Locale(identifier: localeIdentifier), arguments: args)
    }

    func localized(_ key: String, arguments: [CVarArg]) -> String { //修改内容：补一个数组版本，给旧代码用
        let format = NSLocalizedString(key, bundle: bundle, comment: "")
        return String(format: format, locale: Locale(identifier: localeIdentifier), arguments: arguments)
    }

    // MARK: - Date / Number
    func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func formatDateTime(_ date: Date,
                        dateStyle: DateFormatter.Style = .medium,
                        timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    func formatNumber(_ number: Double, maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    // MARK: - Plural（临时版）
    //修改内容：此方法只是“占位替换”，真正复数请用 .stringsdict
    func pluralFallback(_ count: Int, singularKey: String, pluralKey: String) -> String {
        let key = (count == 1) ? singularKey : pluralKey
        return localized(key, count)
    }
}

// MARK: - SwiftUI 辅助：本地化 Text
extension Text {
    @MainActor
    init(localizedKey key: String, manager: LocalizationManager = .shared) {
        self.init(manager.localized(key))
    }
}

// MARK: - String 扩展（兼容旧代码）
extension String {
    @MainActor
    func localized(comment: String = "") -> String {
        LocalizationManager.shared.localized(self)
    }

    @MainActor
    func localized(with arguments: CVarArg..., comment: String = "") -> String { //修改内容：正确传递 varargs
        LocalizationManager.shared.localized(self, arguments: arguments)
    }

    @MainActor
    func localized(with arguments: [CVarArg], comment: String = "") -> String { //修改内容：新增数组版本
        LocalizationManager.shared.localized(self, arguments: arguments)
    }
}
