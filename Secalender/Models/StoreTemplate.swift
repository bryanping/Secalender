//
//  StoreTemplate.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  模板市集的付费模板数据模型
//
//  注意：此 StoreTemplate 与以下概念不同：
//  - SavedTripTemplate: 用户保存的AI生成的行程模板（存储在本地）
//  - Event: 实际的行程事件（存储在 Firebase）
//  - MultiDayEventItem: 多日行程的临时UI状态（不存储）
//
//  此 StoreTemplate 仅用于模板市集的展示和购买，不包含实际行程数据。
//  如需将模板转换为行程，需要通过 API 获取完整的 PlanResult 数据。
//

import Foundation

/// 模板市集博主／創作者
struct TemplateCreator: Identifiable, Equatable {
    let id: String
    let name: String
    let avatarURL: String?
    let bio: String?
    let followerCount: Int
    let templateCount: Int
    
    init(
        id: String,
        name: String,
        avatarURL: String? = nil,
        bio: String? = nil,
        followerCount: Int = 0,
        templateCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.bio = bio
        self.followerCount = followerCount
        self.templateCount = templateCount
    }
}

/// 市集模板分類（用於篩選與導航）
enum StoreTemplateCategory: String, CaseIterable, Codable {
    case all = "all"
    case popular = "popular"
    case newArrivals = "new_arrivals"
    case creators = "creators"
    case japan = "japan"
    case taiwan = "taiwan"
    case korea = "korea"
    case europe = "europe"
    
    var displayTag: String? {
        switch self {
        case .all: return nil
        case .popular: return nil
        case .newArrivals: return nil
        case .creators: return nil
        case .japan: return "日本"
        case .taiwan: return "台灣"
        case .korea: return "韓國"
        case .europe: return "歐洲"
        }
    }
}

/// 模板市集的付费模板（Store Template）
///
/// 用途：模板市集中展示和购买的付费模板
/// 存储：PostgreSQL `templates` 表（通过 SecalenderWeb API）
/// 特点：只包含基本信息，不包含实际行程数据（PlanResult）
///
/// 与 Event 的区别：
/// - StoreTemplate: 模板（可购买），存储在 PostgreSQL
/// - Event: 实际行程事件，存储在 Firebase Firestore
///
/// 与 SavedTripTemplate 的区别：
/// - StoreTemplate: 付费模板，存储在 PostgreSQL
/// - SavedTripTemplate: 用户保存的AI生成的行程模板，存储在本地 UserDefaults
struct StoreTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let tags: [String]
    let price: Double
    let category: String?
    let coverImageURL: String?
    let rating: Double?
    let purchaseCount: Int
    let daysCount: Int
    let authorName: String?
    let creatorId: String?
    let isFeatured: Bool
    let createdAt: Date?
    
    var isFree: Bool { price == 0 }
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        tags: [String],
        price: Double,
        category: String? = nil,
        coverImageURL: String? = nil,
        rating: Double? = nil,
        purchaseCount: Int = 0,
        daysCount: Int = 3,
        authorName: String? = nil,
        creatorId: String? = nil,
        isFeatured: Bool = false,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.tags = tags
        self.price = price
        self.category = category
        self.coverImageURL = coverImageURL
        self.rating = rating
        self.purchaseCount = purchaseCount
        self.daysCount = daysCount
        self.authorName = authorName
        self.creatorId = creatorId
        self.isFeatured = isFeatured
        self.createdAt = createdAt
    }
    
    static func == (lhs: StoreTemplate, rhs: StoreTemplate) -> Bool {
        lhs.id == rhs.id
    }
}
