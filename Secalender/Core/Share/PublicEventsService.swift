//
//  PublicEventsService.swift
//  Secalender
//
//  修改内容：時事活動 — 讀取全域公開活動 `public_events`（官方時間線，如 2026 世界盃 104 場賽事，
//  由 SecalenderWeb/tools/seed_worldcup.js 寫入）。所有使用者可見；規則：公開讀、僅管理端寫。
//

import Foundation
import FirebaseFirestore

struct PublicEventItem: Identifiable {
    let id: String
    let title: String
    let startAt: Date
    let endAt: Date
    let location: String?
    let category: String?
}

final class PublicEventsService {
    static let shared = PublicEventsService()
    private let db = Firestore.firestore()
    private init() {}

    /// 即將到來的公開活動（今天起，依時間升序）
    func fetchUpcoming(limit: Int = 20) async -> [PublicEventItem] {
        do {
            let snapshot = try await db.collection("public_events")
                .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: Calendar.current.startOfDay(for: Date())))
                .order(by: "startAt")
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let start = (data["startAt"] as? Timestamp)?.dateValue() else { return nil }
                let end = (data["endAt"] as? Timestamp)?.dateValue() ?? start.addingTimeInterval(7200)
                return PublicEventItem(
                    id: doc.documentID,
                    title: title,
                    startAt: start,
                    endAt: end,
                    location: data["location"] as? String,
                    category: data["category"] as? String
                )
            }
        } catch {
            print("⚠️ [PublicEventsService] 讀取失敗: \(error.localizedDescription)")
            return []
        }
    }
}
