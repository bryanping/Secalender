//
//  ApplyPlan.swift
//  Secalender
//
//  修改內容：預覽與套用一致性 — 套用前的純邏輯（無 Firebase 依賴，可單元測試）：
//  1. 候選 → TimeItem 轉換，並產生穩定 document id（同 requestId + candidateId 重試不重複建立）
//  2. 缺時間候選不靜默跳過：直接套用時列入 skippedNoTime；存為建議時轉為 task（待安排）
//  3. ApplyOutcome：回傳實際寫入 / 未排入 / 失敗的候選 ID，供來源頁只消耗真正成功的項目
//

import Foundation

/// 套用結果（實際寫入狀況）
struct ApplyOutcome: Equatable {
    struct Failure: Equatable {
        let candidateId: String
        let reason: String
    }

    /// 本次套用使用的 requestId（重試時沿用可去重）
    var requestId: String
    /// 已成功寫入的候選 ID
    var appliedCandidateIds: [String] = []
    /// candidateId → time_items document id
    var writtenItemIds: [String: String] = [:]
    /// 缺時間、未寫入的候選 ID（保留待安排）
    var skippedNoTimeIds: [String] = []
    /// 寫入失敗的候選（可重試）
    var failures: [Failure] = []

    var appliedCount: Int { appliedCandidateIds.count }
    var skippedCount: Int { skippedNoTimeIds.count }
    var failedCount: Int { failures.count }
    var hasAnyApplied: Bool { appliedCount > 0 }
    var isFullSuccess: Bool { failedCount == 0 && skippedCount == 0 && appliedCount > 0 }

    /// 已成功寫入的來源項目 ID（TimeItemCandidate.sourceItemId），供來源頁標記「已安排」
    var appliedSourceItemIds: Set<String> = []

    /// 使用者可讀摘要
    var summaryText: String {
        var parts: [String] = []
        if appliedCount > 0 { parts.append("已加入 \(appliedCount) 項") }
        if skippedCount > 0 { parts.append("\(skippedCount) 項因無可用時間保留待安排") }
        if failedCount > 0 { parts.append("\(failedCount) 項寫入失敗，可重試") }
        if parts.isEmpty { return "沒有項目被加入" }
        return parts.joined(separator: "；")
    }
}

/// 套用模式
enum ApplyMode {
    case event        // 直接套用 → time_items(type=event)
    case suggestion   // 存為建議 → time_items(type=suggestion)；缺時間 → task
}

enum ApplyPlanBuilder {

    /// 穩定 document id：同一 requestId + candidateId 永遠相同 → upsert(merge) 冪等，連點 / 重試不重複建立
    static func stableItemId(requestId: String, candidateId: String, mode: ApplyMode) -> String {
        let prefix = mode == .event ? "gen" : "sug"
        return sanitize("\(prefix)_\(requestId)_\(candidateId)")
    }

    /// Firestore document id 僅允許安全字元；避免 "/"、"." 等
    static func sanitize(_ raw: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        let cleaned = String(raw.map { allowed.contains($0) ? $0 : "_" })
        return String(cleaned.prefix(200))
    }

    struct BuildResult: Equatable {
        struct Entry: Equatable {
            let candidateId: String
            let sourceItemId: String?
            let item: TimeItem
        }
        var entries: [Entry] = []
        var skippedNoTimeIds: [String] = []
    }

    /// 候選 → TimeItem；依 mode 決定型別與缺時間處理
    static func build(
        candidates: [TimeItemCandidate],
        requestId: String,
        themeKey: String?,
        mode: ApplyMode,
        now: Date = Date()
    ) -> BuildResult {
        var result = BuildResult()
        var seen = Set<String>()
        for c in candidates {
            // 同一批內重複候選 ID 只寫一次
            guard !seen.contains(c.id) else { continue }
            seen.insert(c.id)

            let docId = stableItemId(requestId: requestId, candidateId: c.id, mode: mode)
            switch mode {
            case .event:
                guard let s = c.startAt, let e = c.endAt, e > s else {
                    result.skippedNoTimeIds.append(c.id)
                    continue
                }
                let item = TimeItem(
                    id: docId,
                    type: .event,
                    title: c.title,
                    notes: c.notes,
                    startAt: s,
                    endAt: e,
                    hasStartAt: true,
                    durationMin: Int(e.timeIntervalSince(s) / 60),
                    themeKey: themeKey,
                    requestId: requestId,
                    source: .ai,
                    status: .active,
                    createdAt: now,
                    updatedAt: now,
                    linkedTaskId: c.sourceItemId
                )
                result.entries.append(.init(candidateId: c.id, sourceItemId: c.sourceItemId, item: item))

            case .suggestion:
                if let s = c.startAt, let e = c.endAt, e > s {
                    var item = TimeItem.suggestion(
                        title: c.title,
                        startAt: s,
                        endAt: e,
                        linkedTaskId: c.sourceItemId,
                        notes: c.notes,
                        themeKey: themeKey
                    )
                    item.id = docId
                    item.requestId = requestId
                    item.createdAt = now
                    item.updatedAt = now
                    result.entries.append(.init(candidateId: c.id, sourceItemId: c.sourceItemId, item: item))
                } else {
                    // 缺時間 → 待安排任務，不靜默丟棄
                    var item = TimeItem.task(
                        title: c.title,
                        durationMin: c.durationMin ?? 60,
                        notes: c.notes,
                        themeKey: themeKey,
                        source: .ai
                    )
                    item.id = docId
                    item.requestId = requestId
                    item.createdAt = now
                    item.updatedAt = now
                    result.entries.append(.init(candidateId: c.id, sourceItemId: c.sourceItemId, item: item))
                }
            }
        }
        return result
    }
}
