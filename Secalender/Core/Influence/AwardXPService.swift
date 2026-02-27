//
//  AwardXPService.swift
//  Secalender
//
//  呼叫 Cloud Function awardXP 發放經驗值與獎章
//  XP 僅由 Server 發放，Client 只負責呼叫此 Function
//

import Foundation
import FirebaseAuth
import FirebaseFunctions

/// 呼叫 awardXP Cloud Function 的服務
enum AwardXPService {

    private static var functions: Functions {
        Functions.functions(region: "asia-east1")
    }

    /// 發放 XP
    /// - Parameters:
    ///   - actionType: 行為類型（create_event, ai_generate_plan 等）
    ///   - dedupeKey: 去重鍵，格式 {actionType}:{entityId}
    ///   - medalInput: 獎章判定輸入（score 0~100、elapsedSec、socialValue）
    ///   - metricKey: 可選，額外累加到某 metrics key
    /// - Returns: 成功回傳 result，失敗回傳 nil（可 fallback 到舊的 InfluenceDataManager）
    static func awardXP(
        actionType: String,
        dedupeKey: String,
        medalInput: [String: Any]? = nil,
        metricKey: String? = nil
    ) async -> [String: Any]? {
        guard Auth.auth().currentUser != nil else { return nil }
        var data: [String: Any] = [
            "actionType": actionType,
            "dedupeKey": dedupeKey
        ]
        if let m = medalInput { data["medalInput"] = m }
        if let k = metricKey { data["metricKey"] = k }

        do {
            let result = try await functions.httpsCallable("awardXP").call(data)
            return result.data as? [String: Any]
        } catch {
            print("⚠️ AwardXPService awardXP failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// 品質分 0~100（行程完整度、AI 品質等）
    static func qualityScore(title: String?, hasLocation: Bool, hasTime: Bool, itemCount: Int) -> Int {
        var score = 30
        if let t = title, !t.isEmpty { score += 15 }
        if hasLocation { score += 20 }
        if hasTime { score += 15 }
        if itemCount >= 3 { score += 10 }
        if itemCount >= 5 { score += 10 }
        return min(100, score)
    }
}
