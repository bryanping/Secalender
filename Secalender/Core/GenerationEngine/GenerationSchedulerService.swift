//
//  GenerationSchedulerService.swift
//  Secalender
//
//  1.0 只處理 untimedPlan、taskOnly：將無時間候選塞入空檔，回傳帶時間的候選。
//  不處理：已有完整時間的 itinerary 重排、自動覆蓋既有 event、高級交通優化、局部 regenerate。
//

import Foundation

/// 空檔時段（與 Core/SchedulerService 邏輯一致）
struct GenerationTimeSlot {
    let start: Date
    let end: Date
    var durationMin: Int { max(1, Int(end.timeIntervalSince(start) / 60)) }
}

final class GenerationSchedulerService {
    static let shared = GenerationSchedulerService()
    private let minSlotMinutes = 15
    private init() {}

    /// 將 untimed/taskOnly 候選塞入 context 的空檔，回傳帶 startAt/endAt 的候選（順序盡量保持）
    func schedule(
        untimedCandidates: [TimeItemCandidate],
        rangeStart: Date,
        rangeEnd: Date,
        existingItems: [TimeItem]
    ) -> [TimeItemCandidate] {
        let gaps = computeGaps(rangeStart: rangeStart, rangeEnd: rangeEnd, fixedItems: existingItems)
        var used: [(Int, Date, Date)] = []
        var result: [TimeItemCandidate] = []
        let sorted = untimedCandidates.sorted { (a, b) in
            let da = a.durationMin ?? 60
            let db = b.durationMin ?? 60
            return da >= db
        }
        for c in sorted {
            let duration = c.durationMin ?? 60
            guard duration >= minSlotMinutes else { continue }
            for (idx, gap) in gaps.enumerated() {
                guard gap.durationMin >= duration else { continue }
                let usedInGap = used.filter { $0.0 == idx }.sorted { $0.1 < $1.1 }
                var candidateStart = gap.start
                for (_, _, ue) in usedInGap {
                    if candidateStart < ue { candidateStart = ue }
                }
                let candidateEnd = candidateStart.addingTimeInterval(TimeInterval(duration * 60))
                if candidateEnd <= gap.end {
                    var scheduled = c
                    scheduled.startAt = candidateStart
                    scheduled.endAt = candidateEnd
                    result.append(scheduled)
                    used.append((idx, candidateStart, candidateEnd))
                    break
                }
            }
        }
        return result
    }

    private func computeGaps(rangeStart: Date, rangeEnd: Date, fixedItems: [TimeItem]) -> [GenerationTimeSlot] {
        var blocked: [(Date, Date)] = fixedItems.compactMap { item in
            guard let s = item.startAt, let e = item.endAt else { return nil }
            return (s, e)
        }
        blocked.sort { $0.0 < $1.0 }
        var gaps: [GenerationTimeSlot] = []
        var cursor = rangeStart
        for (s, e) in blocked {
            if cursor < s {
                let slot = GenerationTimeSlot(start: cursor, end: min(s, rangeEnd))
                if slot.durationMin >= minSlotMinutes { gaps.append(slot) }
            }
            if e > cursor { cursor = e }
            if cursor >= rangeEnd { break }
        }
        if cursor < rangeEnd {
            let slot = GenerationTimeSlot(start: cursor, end: rangeEnd)
            if slot.durationMin >= minSlotMinutes { gaps.append(slot) }
        }
        return gaps
    }
}
