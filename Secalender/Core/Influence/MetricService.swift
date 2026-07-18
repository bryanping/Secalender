//
//  MetricService.swift
//  Secalender
//
//  純計數埋點：呼叫 Cloud Function recordMetric（不發 XP、不觸發成就）
//  供回顧頁社交統計使用
//

import Foundation
import FirebaseAuth
import FirebaseFunctions

enum MetricService {

    private static var functions: Functions {
        Functions.functions(region: "asia-east1")
    }

    /// 累加一個計數指標（dedupeKey 去重）
    /// - Parameters:
    ///   - metricKey: 指標鍵，格式 [a-z0-9_]{1,40}
    ///   - dedupeKey: 去重鍵，格式 {metricKey}:{entityId}
    /// - Returns: 成功回傳 result，失敗回傳 nil
    @discardableResult
    static func record(metricKey: String, dedupeKey: String, contactId: String? = nil, displayName: String = "") async -> [String: Any]? {
        guard Auth.auth().currentUser != nil else { return nil }
        var data: [String: Any] = [
            "metricKey": metricKey,
            "dedupeKey": dedupeKey
        ]
        if let cid = contactId, !cid.isEmpty {
            data["contactId"] = cid
            data["displayName"] = displayName
        }
        do {
            let result = try await functions.httpsCallable("recordMetric").call(data)
            return result.data as? [String: Any]
        } catch {
            print("⚠️ MetricService record failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// 拉取回顧頁資料
    static func fetchReviewSummary(staleDays: Int = 60) async -> [String: Any]? {
        guard Auth.auth().currentUser != nil else { return nil }
        do {
            let result = try await functions.httpsCallable("getReviewSummary")
                .call(["staleDays": staleDays])
            return result.data as? [String: Any]
        } catch {
            print("⚠️ MetricService fetchReviewSummary failed: \(error.localizedDescription)")
            return nil
        }
    }
}
