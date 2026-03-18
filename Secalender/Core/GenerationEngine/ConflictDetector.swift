//
//  ConflictDetector.swift
//  Secalender
//
//  1.0 至少：event overlap、block overlap 基本檢測；不可永遠回空陣列。
//

import Foundation

final class ConflictDetector {
    static let shared = ConflictDetector()
    private init() {}

    /// 檢測候選與現有 event/block 重疊
    func detect(candidates: [TimeItemCandidate], existingItems: [TimeItem]) -> [ConflictInfo] {
        var conflicts: [ConflictInfo] = []
        for c in candidates {
            guard let start = c.startAt, let end = c.endAt else { continue }
            for item in existingItems {
                guard let is_ = item.startAt, let ie_ = item.endAt else { continue }
                if start < ie_ && end > is_ {
                    let kind = item.type == .block ? "block" : "event"
                    conflicts.append(ConflictInfo(
                        title: "與現有\(kind)重疊",
                        detail: "「\(c.title)」與「\(item.title)」時間重疊",
                        candidateId: c.id,
                        existingItemId: item.id,
                        startAt: start,
                        endAt: end
                    ))
                }
            }
        }
        return conflicts
    }
}
