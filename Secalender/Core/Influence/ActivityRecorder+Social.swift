//
//  ActivityRecorder+Social.swift
//  Secalender
//
//  社交軸埋點：純計數 metrics，供回顧頁統計（不發 XP）
//  metricKey: stat_event_with_people / stat_attend_event / stat_unique_contact
//  share_event 仍走 AwardXPService（本身為有 XP 的社交行為）
//

import Foundation
import FirebaseAuth

extension ActivityRecorder {

    /// 分享/邀請他人加入行程（沿用既有 share_event，含 XP 與 count）
    static func recordEventShared(eventId: String, socialValue: Int = 0) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        Task { @MainActor in
            let dedupeKey = GamificationKit.makeDedupeKey(actionType: "share_event", entityId: eventId)
            _ = await AwardXPService.awardXP(
                actionType: "share_event",
                dedupeKey: dedupeKey,
                medalInput: ["socialValue": socialValue]
            )
        }
    }

    /// 建立含參與者(≥1)的行程 → metrics.stat_event_with_people
    static func recordEventWithPeople(eventId: String, participantCount: Int) {
        guard participantCount >= 1 else { return }
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        Task { @MainActor in
            let dedupeKey = GamificationKit.makeDedupeKey(actionType: "stat_event_with_people", entityId: eventId)
            await MetricService.record(metricKey: "stat_event_with_people", dedupeKey: dedupeKey)
        }
    }

    /// 標記赴約/完成一場有人的活動 → metrics.stat_attend_event
    static func recordEventAttended(eventId: String) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        Task { @MainActor in
            let dedupeKey = GamificationKit.makeDedupeKey(actionType: "stat_attend_event", entityId: eventId)
            await MetricService.record(metricKey: "stat_attend_event", dedupeKey: dedupeKey)
        }
    }

    /// 互動對象去重計數 + 更新最近互動時間
    /// → metrics.stat_unique_contact（每個 contactId 只計一次）
    /// → contactStats/{contactId}.lastInteractAt（每次刷新，供關係維護提醒）
    /// - Parameter contacts: (contactId, displayName)
    static func recordUniqueContacts(_ contacts: [(id: String, name: String)]) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else { return }
        let valid = contacts.filter { !$0.id.isEmpty }
        guard !valid.isEmpty else { return }
        var seen = Set<String>()
        Task { @MainActor in
            for c in valid where seen.insert(c.id).inserted {
                let dedupeKey = GamificationKit.makeDedupeKey(actionType: "stat_unique_contact", entityId: c.id)
                await MetricService.record(
                    metricKey: "stat_unique_contact",
                    dedupeKey: dedupeKey,
                    contactId: c.id,
                    displayName: c.name
                )
            }
        }
    }
}
