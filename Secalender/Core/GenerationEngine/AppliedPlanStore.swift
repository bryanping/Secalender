//
//  AppliedPlanStore.swift
//  Secalender
//
//  修改内容：整體行程 — 套用到時間表的 PlanResult 快照（以 requestId 為鍵，按帳號隔離）
//  行事曆點選任一投影項目時，可據此重新開啟整份行程的編輯頁，而非單一行程頁。
//

import Foundation

struct AppliedPlanSnapshot: Codable {
    var requestId: String
    var title: String?
    var plan: PlanResult
    var themeKey: String?
    var appliedAt: Date
}

final class AppliedPlanStore {
    static let shared = AppliedPlanStore()
    private init() {}

    private let defaults = UserDefaults.standard
    private func key(_ userId: String) -> String { "applied_plans_\(userId)" }

    private func load(_ userId: String) -> [String: AppliedPlanSnapshot] {
        guard let data = defaults.data(forKey: key(userId)),
              let dict = try? JSONDecoder().decode([String: AppliedPlanSnapshot].self, from: data) else { return [:] }
        return dict
    }

    private func save(_ dict: [String: AppliedPlanSnapshot], _ userId: String) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        defaults.set(data, forKey: key(userId))
    }

    func upsert(_ snapshot: AppliedPlanSnapshot, userId: String) {
        guard !userId.isEmpty else { return }
        var dict = load(userId)
        dict[snapshot.requestId] = snapshot
        // 只保留最近 50 份
        if dict.count > 50 {
            let sorted = dict.values.sorted { $0.appliedAt > $1.appliedAt }.prefix(50)
            dict = Dictionary(uniqueKeysWithValues: sorted.map { ($0.requestId, $0) })
        }
        save(dict, userId)
    }

    func snapshot(requestId: String, userId: String) -> AppliedPlanSnapshot? {
        load(userId)[requestId]
    }

    func remove(requestId: String, userId: String) {
        var dict = load(userId)
        dict.removeValue(forKey: requestId)
        save(dict, userId)
    }
}
