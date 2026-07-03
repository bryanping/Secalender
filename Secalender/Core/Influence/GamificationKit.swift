//
//  GamificationKit.swift
//  Secalender
//
//  等級曲線（36*(L-1)^2）、XP 上限 32767、獎章等級、進度計算、dedupeKey
//  參考 GPT 設計，與 Cloud Functions awardXP 一致
//

import Foundation

// MARK: - 獎章等級（銅/銀/金/白金）
enum Medal: String, CaseIterable, Codable {
    case bronze
    case silver
    case gold
    case platinum
    
    @MainActor
    var displayName: String {
        switch self {
        case .bronze: return "medal.bronze".localized()
        case .silver: return "medal.silver".localized()
        case .gold: return "medal.gold".localized()
        case .platinum: return "medal.platinum".localized()
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1
        case .gold: return 2
        case .platinum: return 3
        }
    }
    
    /// SF Symbol 或顏色用於 UI
    var iconName: String {
        switch self {
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "medal.fill"
        case .platinum: return "medal.fill"
        }
    }
    
    var colorHex: String {
        switch self {
        case .bronze: return "#CD7F32"
        case .silver: return "#C0C0C0"
        case .gold: return "#FFD700"
        case .platinum: return "#E5E4E2"
        }
    }
}

// MARK: - 成就類別（含隱藏）
enum AchievementCategory: String, CaseIterable, Codable {
    case basic = "basic"
    case feature = "feature"
    case social = "social"
    case hidden = "hidden"
    
    var isHidden: Bool { self == .hidden }
}

// MARK: - 徽章稀有度
enum BadgeRarity: String, CaseIterable, Codable {
    case common
    case rare
    case epic
    case legendary
    case verified
}

// MARK: - GamificationKit
struct GamificationKit {
    
    static let xpCap: Int = 32767
    static let maxLevel: Int = 31
    
    /// 等級門檻：threshold(L) = 36 * (L-1)^2
    static func threshold(level: Int) -> Int {
        let l = max(level, 1)
        return 36 * (l - 1) * (l - 1)
    }
    
    /// 從 totalXP 計算當前等級
    static func level(forXP xp: Int) -> Int {
        let clamped = min(max(xp, 0), xpCap)
        var lo = 1
        var hi = maxLevel
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if threshold(level: mid) <= clamped {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo
    }
    
    /// 進度：(level, progress 0~1, currentThreshold, nextThreshold)
    static func progress(forXP xp: Int) -> (level: Int, progress: Double, current: Int, next: Int) {
        let lv = level(forXP: xp)
        let cur = threshold(level: lv)
        let next = lv < maxLevel ? threshold(level: lv + 1) : xpCap
        let denom = max(next - cur, 1)
        let p = Double(min(max(xp - cur, 0), denom)) / Double(denom)
        return (lv, p, cur, next)
    }
    
    /// 生成 dedupeKey（與 entityId 綁定，避免重複領取）
    static func makeDedupeKey(actionType: String, entityId: String) -> String {
        "\(actionType):\(entityId)"
    }
    
    /// 品質分轉獎章（client 算 score 0~100，server 最終判定）
    static func medalFromScore(_ score: Int, silverMin: Int = 50, goldMin: Int = 70, platinumMin: Int = 90) -> Medal {
        if score >= platinumMin { return .platinum }
        if score >= goldMin { return .gold }
        if score >= silverMin { return .silver }
        return .bronze
    }
}
