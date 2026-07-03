//
//  ActivityRecorder.swift
//  Secalender
//
//  活動紀錄入口：優先呼叫 Cloud Function awardXP，失敗時 fallback 到 InfluenceDataManager
//

import Foundation
import FirebaseAuth

/// 活動紀錄器：統一入口，供 EventManager、CreateTripTemplateView、AIPlannerView 等呼叫
enum ActivityRecorder {

    /// 活動創建完成後呼叫
    static func recordEventCreated(title: String, eventId: String, visibility: Int, hasLocation: Bool = false, hasTime: Bool = false, itemCount: Int = 0) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        Task { @MainActor in
            let dedupeKey = GamificationKit.makeDedupeKey(actionType: "create_event", entityId: eventId)
            let score = AwardXPService.qualityScore(title: title, hasLocation: hasLocation, hasTime: hasTime, itemCount: itemCount)
            let result = await AwardXPService.awardXP(
                actionType: "create_event",
                dedupeKey: dedupeKey,
                medalInput: ["score": score]
            )
            if result == nil {
                await InfluenceDataManager.shared.recordEventCreated(userId: userId, title: title, eventId: eventId, visibility: visibility)
            } else {
                await InfluenceDataManager.shared.addActivityLogOnly(userId: userId, type: .eventCreated, title: title, itemId: eventId, visibility: visibilityString(visibility))
                await InfluenceDataManager.shared.load(for: userId)
            }
        }
    }

    /// 參與活動（接受邀請）後呼叫
    static func recordEventParticipated(eventId: String = UUID().uuidString) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        Task { @MainActor in
            let dedupeKey = GamificationKit.makeDedupeKey(actionType: "complete_event", entityId: eventId)
            let result = await AwardXPService.awardXP(
                actionType: "complete_event",
                dedupeKey: dedupeKey,
                medalInput: ["score": 50]
            )
            if result == nil {
                await InfluenceDataManager.shared.recordEventParticipated(userId: userId)
            } else {
                await InfluenceDataManager.shared.addActivityLogOnly(userId: userId, type: .eventParticipated)
                await InfluenceDataManager.shared.load(for: userId)
            }
        }
    }

    /// 行程模板創建完成後呼叫
    static func recordTemplateCreated(title: String, templateId: String) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        Task { @MainActor in
            let dedupeKey = GamificationKit.makeDedupeKey(actionType: "create_template", entityId: templateId)
            let result = await AwardXPService.awardXP(
                actionType: "create_template",
                dedupeKey: dedupeKey,
                medalInput: ["score": 60]
            )
            if result == nil {
                await InfluenceDataManager.shared.recordTemplateCreated(userId: userId, title: title)
            } else {
                await InfluenceDataManager.shared.addActivityLogOnly(userId: userId, type: .templateCreated, title: title)
                await InfluenceDataManager.shared.load(for: userId)
            }
        }
    }

    /// 自定義主題創建完成後呼叫
    static func recordThemeCreated(title: String, themeId: String) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        Task { @MainActor in
            let dedupeKey = GamificationKit.makeDedupeKey(actionType: "create_theme", entityId: themeId)
            let result = await AwardXPService.awardXP(
                actionType: "create_theme",
                dedupeKey: dedupeKey,
                medalInput: ["score": 60]
            )
            if result == nil {
                await InfluenceDataManager.shared.recordThemeCreated(userId: userId, title: title)
            } else {
                await InfluenceDataManager.shared.addActivityLogOnly(userId: userId, type: .themeCreated, title: title)
                await InfluenceDataManager.shared.load(for: userId)
            }
        }
    }

    /// AI 生成完成後呼叫（planId 預設為 UUID，每次生成視為獨立動作）
    static func recordAIUsed(planId: String = UUID().uuidString, qualityScore: Int = 50) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        Task { @MainActor in
            let dedupeKey = GamificationKit.makeDedupeKey(actionType: "ai_generate_plan", entityId: planId)
            let result = await AwardXPService.awardXP(
                actionType: "ai_generate_plan",
                dedupeKey: dedupeKey,
                medalInput: ["score": qualityScore]
            )
            if result == nil {
                await InfluenceDataManager.shared.recordAIUsed(userId: userId)
            } else {
                await InfluenceDataManager.shared.addActivityLogOnly(userId: userId, type: .aiUsed)
                await InfluenceDataManager.shared.load(for: userId)
            }
        }
    }

    /// 內容發佈後呼叫（公開行程、主題、模板等）
    static func recordContentPublished(title: String, type: String, visibility: String, itemId: String? = nil, socialValue: Int = 0) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        Task { @MainActor in
            let actionType = type == "template" ? "publish_template" : "share_event"
            let entityId = itemId ?? UUID().uuidString
            let dedupeKey = GamificationKit.makeDedupeKey(actionType: actionType, entityId: entityId)
            let result = await AwardXPService.awardXP(
                actionType: actionType,
                dedupeKey: dedupeKey,
                medalInput: ["socialValue": socialValue]
            )
            if result == nil {
                await InfluenceDataManager.shared.recordContentPublished(userId: userId, title: title, type: type, visibility: visibility)
            } else {
                await InfluenceDataManager.shared.addActivityLogOnly(userId: userId, type: .contentPublished, title: title, visibility: visibility, metadata: ["contentType": type])
                await InfluenceDataManager.shared.load(for: userId)
            }
        }
    }

    private static func visibilityString(_ v: Int) -> String {
        switch v {
        case 1: return "public"
        case 2: return "friends"
        default: return "private"
        }
    }
}
