//
//  ApplyStrategy.swift
//  Secalender
//
//  寫入策略：直接套用 → time_items(type=event)；存為建議 → time_items(type=suggestion)。
//  新生成結果一律寫入 time_items，不寫入舊 EventManager 作為主要流程。
//

import Foundation

enum ApplyStrategyError: LocalizedError {
    case notAuthenticated
    var errorDescription: String? { "用戶未登入" }
}

final class ApplyStrategy {
    static let shared = ApplyStrategy()
    private let timeItemService = TimeItemService.shared
    private init() {}

    /// 直接套用：將候選寫入 time_items(type=event)
    func applyDirect(candidates: [TimeItemCandidate], requestId: String?, themeKey: String?) async throws {
        for c in candidates {
            guard let start = c.startAt, let end = c.endAt else { continue }
            let item = TimeItem(
                type: .event,
                title: c.title,
                notes: c.notes,
                startAt: start,
                endAt: end,
                hasStartAt: true,
                themeKey: themeKey,
                requestId: requestId,
                source: .ai,
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = try await timeItemService.upsert(item)
        }
    }

    /// 存為建議：寫入 time_items(type=suggestion)
    func saveAsSuggestion(candidates: [TimeItemCandidate], requestId: String?, themeKey: String?) async throws {
        for c in candidates {
            guard let start = c.startAt, let end = c.endAt else { continue }
            let item = TimeItem.suggestion(
                title: c.title,
                startAt: start,
                endAt: end,
                notes: c.notes,
                themeKey: themeKey
            )
            var withRequest = item
            withRequest.requestId = requestId
            _ = try await timeItemService.upsert(withRequest)
        }
    }

    /// 將 PlanResult 的 days/blocks 轉為候選後套用（兼容從 plan 寫入）
    func applyFromPlan(_ plan: PlanResult, requestId: String?, themeKey: String?) async throws {
        let candidates = GenerationNormalizer.shared.normalize(plan: plan)
        try await applyDirect(candidates: candidates, requestId: requestId, themeKey: themeKey)
    }

    /// 存為建議（從 plan）
    func savePlanAsSuggestion(_ plan: PlanResult, requestId: String?, themeKey: String?) async throws {
        let candidates = GenerationNormalizer.shared.normalize(plan: plan)
        try await saveAsSuggestion(candidates: candidates, requestId: requestId, themeKey: themeKey)
    }
}
