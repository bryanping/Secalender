//
//  ApplyStrategy.swift
//  Secalender
//
//  寫入策略：直接套用 → time_items(type=event)；存為建議 → time_items(type=suggestion)。
//  新生成結果一律寫入 time_items，不寫入舊 EventManager 作為主要流程。
//
//  修改內容：預覽與套用一致性 —
//  - 回傳 ApplyOutcome（已寫入 / 未排入 / 失敗），不再靜默 continue
//  - 逐筆寫入、逐筆收集錯誤：部分成功時回報實際狀況
//  - document id 由 requestId + candidateId 穩定推導 → 連點 / 重試不重複建立
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
    /// - requestId 為 nil 時自動產生；呼叫端重試應沿用回傳的 outcome.requestId
    @discardableResult
    func applyDirect(candidates: [TimeItemCandidate], requestId: String?, themeKey: String?) async -> ApplyOutcome {
        await write(candidates: candidates, requestId: requestId, themeKey: themeKey, mode: .event)
    }

    /// 存為建議：寫入 time_items(type=suggestion)；缺時間候選改存為 task（待安排）
    @discardableResult
    func saveAsSuggestion(candidates: [TimeItemCandidate], requestId: String?, themeKey: String?) async -> ApplyOutcome {
        await write(candidates: candidates, requestId: requestId, themeKey: themeKey, mode: .suggestion)
    }

    /// 將 PlanResult 的 days/blocks 轉為候選後套用（兼容從 plan 寫入）
    @discardableResult
    func applyFromPlan(_ plan: PlanResult, requestId: String?, themeKey: String?) async -> ApplyOutcome {
        let candidates = GenerationNormalizer.shared.normalize(plan: plan)
        return await applyDirect(candidates: candidates, requestId: requestId, themeKey: themeKey)
    }

    /// 存為建議（從 plan）
    @discardableResult
    func savePlanAsSuggestion(_ plan: PlanResult, requestId: String?, themeKey: String?) async -> ApplyOutcome {
        let candidates = GenerationNormalizer.shared.normalize(plan: plan)
        return await saveAsSuggestion(candidates: candidates, requestId: requestId, themeKey: themeKey)
    }

    // MARK: - 共用寫入

    private func write(candidates: [TimeItemCandidate], requestId: String?, themeKey: String?, mode: ApplyMode) async -> ApplyOutcome {
        let rid = (requestId?.isEmpty == false) ? requestId! : UUID().uuidString
        var outcome = ApplyOutcome(requestId: rid)

        let built = ApplyPlanBuilder.build(candidates: candidates, requestId: rid, themeKey: themeKey, mode: mode)
        outcome.skippedNoTimeIds = built.skippedNoTimeIds

        // 修改内容：改為單次批次 commit（逐筆 await 在網路不穩時會卡在第二筆）
        do {
            let ids = try await timeItemService.upsertBatch(built.entries.map { $0.item })
            for (entry, docId) in zip(built.entries, ids) {
                outcome.appliedCandidateIds.append(entry.candidateId)
                outcome.writtenItemIds[entry.candidateId] = docId
                if let src = entry.sourceItemId { outcome.appliedSourceItemIds.insert(src) }
            }
        } catch {
            for entry in built.entries {
                outcome.failures.append(.init(candidateId: entry.candidateId, reason: error.localizedDescription))
            }
        }
        print("✅ [ApplyStrategy] \(mode) 套用完成：\(outcome.summaryText)")
        return outcome
    }
}
