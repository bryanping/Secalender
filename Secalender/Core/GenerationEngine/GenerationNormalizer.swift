//
//  GenerationNormalizer.swift
//  Secalender
//
//  將 PlanResult 標準化為 TimeItemCandidate 列表（供分類、衝突、套用使用）。
//

import Foundation

final class GenerationNormalizer {
    static let shared = GenerationNormalizer()
    private init() {}

    /// 從 PlanResult 產出 candidates；plan 原樣保留供兼容
    func normalize(plan: PlanResult) -> [TimeItemCandidate] {
        var list: [TimeItemCandidate] = []
        for (dayIdx, day) in plan.days.enumerated() {
            for block in day.blocks {
                let type = mapBlockType(block.type)
                let durationMin = block.endTime.timeIntervalSince(block.startTime) / 60
                list.append(TimeItemCandidate(
                    id: block.id.uuidString,
                    title: block.title,
                    notes: block.description,
                    startAt: block.startTime,
                    endAt: block.endTime,
                    durationMin: Int(durationMin),
                    type: type,
                    location: block.location,
                    dayIndex: dayIdx,
                    sourceBlockId: block.id
                ))
            }
        }
        return list
    }

    private func mapBlockType(_ t: TimeBlockType) -> TimeItemCandidateType {
        switch t {
        case .activity: return .activity
        case .transit: return .transit
        case .buffer: return .transit
        case .flex: return .flex
        case .rest: return .rest
        }
    }
}
