//
//  InfluenceStatsModel.swift
//  Secalender
//
//  影響力、成就、活動紀錄的資料模型
//  支援：totalXP（32767 上限）、獎章等級、隱藏成就、Badge
//

import Foundation

// MARK: - 徽章（展示用，可由成就或活動授予）
struct GamificationBadge: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var rarity: BadgeRarity
    var iconUrl: String?
    var isActive: Bool
    var sort: Int
    @MainActor
    var localizedName: String {
        switch id {
        case "badge_newbie": return "badge.newbie".localized()
        case "badge_week_streak": return "badge.week_streak".localized()
        case "badge_ai_master": return "badge.ai_master".localized()
        case "badge_template_creator": return "badge.template_creator".localized()
        case "badge_hidden": return "badge.hidden".localized()
        default: return name
        }
    }
}

// MARK: - 單次獎章記錄（含等級）
struct MedalRecord: Identifiable, Codable {
    var id: String { "\(actionType):\(entityId)" }
    let actionType: String
    let entityId: String
    let medal: Medal
    let baseXP: Int
    let bonusXP: Int
    let createdAt: Date
}

// MARK: - 影響力統計（存於 Firestore users/{userId}/influence_stats）
struct InfluenceStats: Codable, Equatable {
    var level: Int
    var expCurrent: Int
    var expNeeded: Int
    var eventsCreated: Int
    var eventsParticipated: Int
    var templatesCreated: Int
    var themesCreated: Int
    var aiUsageCount: Int
    var weeklyViews: Int
    var weeklyEngagement: Int
    var weeklyShares: Int
    var lastWeekViews: Int
    var lastWeekEngagement: Int
    var lastWeekShares: Int
    var consecutiveCreateDays: Int
    var lastCreateDate: String?  // yyyy-MM-dd
    var updatedAt: Date?
    
    static var `default`: InfluenceStats {
        InfluenceStats(
            level: 1,
            expCurrent: 0,
            expNeeded: 100,
            eventsCreated: 0,
            eventsParticipated: 0,
            templatesCreated: 0,
            themesCreated: 0,
            aiUsageCount: 0,
            weeklyViews: 0,
            weeklyEngagement: 0,
            weeklyShares: 0,
            lastWeekViews: 0,
            lastWeekEngagement: 0,
            lastWeekShares: 0,
            consecutiveCreateDays: 0,
            lastCreateDate: nil,
            updatedAt: nil
        )
    }
}

// MARK: - 活動紀錄類型
enum ActivityLogType: String, Codable, CaseIterable {
    case eventCreated = "event_created"
    case eventParticipated = "event_participated"
    case templateCreated = "template_created"
    case themeCreated = "theme_created"
    case aiUsed = "ai_used"
    case contentPublished = "content_published"
    case contentViewed = "content_viewed"
    case contentLiked = "content_liked"
    case contentShared = "content_shared"
}

// MARK: - 活動紀錄（存於 users/{userId}/activity_logs）
struct ActivityLog: Identifiable, Codable {
    var id: String?
    var type: ActivityLogType
    var title: String?
    var itemId: String?
    var visibility: String?  // public, friends, private
    var metadata: [String: String]?
    var createdAt: Date
    
    init(type: ActivityLogType, title: String? = nil, itemId: String? = nil, visibility: String? = nil, metadata: [String: String]? = nil, createdAt: Date = Date()) {
        self.id = nil
        self.type = type
        self.title = title
        self.itemId = itemId
        self.visibility = visibility
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

// MARK: - 成就定義（含隱藏）
enum AchievementDefinition: String, CaseIterable, Identifiable {
    case pioneer = "pioneer"           // 開路先鋒：創建第一個活動
    case foodie = "foodie"             // 美食達人：創建 5 個含美食的活動
    case photo = "photo"               // 攝影專家：創建 10 個活動
    case social = "social"             // 社交名流：參與 10 個活動
    case collector = "collector"       // 收藏大師：收藏 5 個模板
    case speed = "speed"               // 極速旅者：連續 7 天創建
    case globetrotter = "globetrotter" // 環球旅行者：創建 20 個活動
    case earlyBird = "early_bird"      // 早起鳥：7 天內創建 3 個活動
    case familyTrips = "family_trips"   // 家庭出遊：創建 3 個多人活動
    case lowCarbon = "low_carbon"      // 低碳出行：創建 5 個本地活動
    case creator = "creator"           // 創作者：創建 3 個主題
    case aiExplorer = "ai_explorer"    // AI 探索者：使用 AI 10 次
    case hiddenMystery = "hidden_mystery"  // 隱藏：神秘成就
    
    var id: String { rawValue }
    
    /// 是否為隱藏成就（未解鎖時顯示 ???）
    var isHidden: Bool {
        switch self {
        case .hiddenMystery: return true
        default: return false
        }
    }
    
    var icon: String {
        switch self {
        case .pioneer: return "location.north.fill"
        case .foodie: return "fork.knife"
        case .photo: return "camera.fill"
        case .social: return "person.3.fill"
        case .collector: return "bookmark.fill"
        case .speed: return "figure.walk"
        case .globetrotter: return "globe.americas.fill"
        case .earlyBird: return "sunrise.fill"
        case .familyTrips: return "person.2.fill"
        case .lowCarbon: return "leaf.fill"
        case .creator: return "paintbrush.fill"
        case .aiExplorer: return "sparkles"
        case .hiddenMystery: return "questionmark.circle.fill"
        }
    }
    
    var localizedKey: String {
        switch self {
        case .pioneer: return "member.achievement_pioneer"
        case .foodie: return "member.achievement_foodie"
        case .photo: return "member.achievement_photo"
        case .social: return "member.achievement_social"
        case .collector: return "member.achievement_collector"
        case .speed: return "member.achievement_speed"
        case .globetrotter: return "member.achievement_globetrotter"
        case .earlyBird: return "achievements.early_bird.title"
        case .familyTrips: return "achievements.family_trips.title"
        case .lowCarbon: return "achievements.low_carbon.title"
        case .creator: return "member.achievement_creator"
        case .aiExplorer: return "member.achievement_ai_explorer"
        case .hiddenMystery: return "achievement.hidden"
        }
    }
    
    var targetCount: Int {
        switch self {
        case .pioneer: return 1
        case .foodie: return 5
        case .photo: return 10
        case .social: return 10
        case .collector: return 5
        case .speed: return 7
        case .globetrotter: return 20
        case .earlyBird: return 3
        case .familyTrips: return 3
        case .lowCarbon: return 5
        case .creator: return 3
        case .aiExplorer: return 10
        case .hiddenMystery: return 1  // 神秘條件
        }
    }
}
@MainActor
// MARK: - 成就進度（用於 UI，含獎章等級）
struct AchievementProgressWithMedal: Identifiable {
    var id: String { definition.rawValue }
    let definition: AchievementDefinition
    var current: Int
    var isUnlocked: Bool
    var bestMedal: Medal?  // 該成就最高獲得的獎章
    
    var progress: Double {
        guard definition.targetCount > 0 else { return 0 }
        return min(1.0, Double(current) / Double(definition.targetCount))
    }
    
    var displayName: String {
        if definition.isHidden && !isUnlocked {
            return "???"
        }
        return definition.localizedKey.localized()
    }
}

// MARK: - 成就進度（用於 UI）
struct AchievementProgress: Identifiable {
    var id: String { definition.rawValue }
    let definition: AchievementDefinition
    var current: Int
    var isUnlocked: Bool
    
    var progress: Double {
        guard definition.targetCount > 0 else { return 0 }
        return min(1.0, Double(current) / Double(definition.targetCount))
    }
}
