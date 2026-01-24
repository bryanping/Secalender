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
struct StoreTemplate: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let tags: [String]
    let price: Double
    
    init(id: UUID = UUID(), title: String, description: String, tags: [String], price: Double) {
        self.id = id
        self.title = title
        self.description = description
        self.tags = tags
        self.price = price
    }
}
