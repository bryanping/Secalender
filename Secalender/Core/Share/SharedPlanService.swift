//
//  SharedPlanService.swift
//  Secalender
//
//  修改内容：分享整併 — 「發送給成員確認」改為發佈可跨平台開啟的網頁連結。
//  安排寫入 Firestore `shared_plans/{shareId}`（公開可讀），
//  成員在任何平台（LINE/WhatsApp/瀏覽器）開 https://secalender.com/plan.html?id={shareId} 即可讀取內容。
//  ⚠️ Firestore 規則需允許 shared_plans 公開讀、登入者寫（見部署備註）。
//

import Foundation
import FirebaseFirestore

final class SharedPlanService {
    static let shared = SharedPlanService()
    private let db = Firestore.firestore()
    private let collectionName = "shared_plans"
    static let webBaseURL = "https://secalender.com/plan.html"

    private init() {}

    /// 發佈安排為公開網頁；回傳分享連結（失敗回 nil，呼叫端退回純文字分享）
    func publish(
        title: String,
        candidates: [TimeItemCandidate],
        creatorId: String,
        creatorName: String?
    ) async -> URL? {
        guard !candidates.isEmpty else { return nil }
        let shareId = Self.randomId(8)
        let items: [[String: Any]] = candidates.map { c in
            var dict: [String: Any] = ["title": c.title]
            if let s = c.startAt { dict["startAt"] = Timestamp(date: s) }
            if let e = c.endAt { dict["endAt"] = Timestamp(date: e) }
            if let n = c.notes, !n.isEmpty { dict["notes"] = n }
            if let l = c.location, !l.isEmpty { dict["location"] = l }
            if let d = c.durationMin { dict["durationMin"] = d }
            return dict
        }
        let data: [String: Any] = [
            "title": title,
            "creatorId": creatorId,
            "creatorName": creatorName ?? "",
            "items": items,
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection(collectionName).document(shareId).setData(data)
            return URL(string: "\(Self.webBaseURL)?id=\(shareId)")
        } catch {
            print("⚠️ [SharedPlanService] 發佈失敗: \(error.localizedDescription)")
            return nil
        }
    }

    private static func randomId(_ length: Int) -> String {
        let chars = "abcdefghjkmnpqrstuvwxyz23456789"
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }
}
