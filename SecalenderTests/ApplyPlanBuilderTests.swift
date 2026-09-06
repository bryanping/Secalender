//
//  ApplyPlanBuilderTests.swift
//  SecalenderTests
//
//  修改內容：預覽與套用一致性 — 純邏輯測試（不需 Firebase）
//  Target 需包含：ApplyPlan.swift、TimeItem.swift、TimeItemCandidate.swift、
//  GenerationNormalizer.swift、PlanGenerator.swift（TimeBlock/DayPlan/PlanResult）、ConflictDetector.swift、GenerationResult.swift
//

import XCTest
@testable import Secalender

final class ApplyPlanBuilderTests: XCTestCase {

    private func date(_ h: Int, _ m: Int = 0, day: Int = 1) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = day; c.hour = h; c.minute = m
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    // MARK: - 去重：同 requestId + candidateId → 同 document id

    func testStableItemIdIsDeterministic() {
        let a = ApplyPlanBuilder.stableItemId(requestId: "req-1", candidateId: "cand-A", mode: .event)
        let b = ApplyPlanBuilder.stableItemId(requestId: "req-1", candidateId: "cand-A", mode: .event)
        XCTAssertEqual(a, b)
    }

    func testStableItemIdDiffersByRequestCandidateAndMode() {
        let base = ApplyPlanBuilder.stableItemId(requestId: "req-1", candidateId: "c", mode: .event)
        XCTAssertNotEqual(base, ApplyPlanBuilder.stableItemId(requestId: "req-2", candidateId: "c", mode: .event))
        XCTAssertNotEqual(base, ApplyPlanBuilder.stableItemId(requestId: "req-1", candidateId: "d", mode: .event))
        XCTAssertNotEqual(base, ApplyPlanBuilder.stableItemId(requestId: "req-1", candidateId: "c", mode: .suggestion))
    }

    func testSanitizeRemovesFirestoreUnsafeChars() {
        let id = ApplyPlanBuilder.sanitize("a/b.c d")
        XCTAssertFalse(id.contains("/"))
        XCTAssertFalse(id.contains("."))
        XCTAssertFalse(id.contains(" "))
    }

    func testDuplicateCandidateIdsInOneBatchWrittenOnce() {
        let c = TimeItemCandidate(id: "dup", title: "x", startAt: date(9), endAt: date(10))
        let r = ApplyPlanBuilder.build(candidates: [c, c], requestId: "r", themeKey: nil, mode: .event)
        XCTAssertEqual(r.entries.count, 1)
    }

    // MARK: - 缺時間不靜默跳過

    func testEventModeReportsSkippedNoTime() {
        let timed = TimeItemCandidate(id: "t", title: "有時間", startAt: date(9), endAt: date(10))
        let untimed = TimeItemCandidate(id: "u", title: "沒時間", durationMin: 30)
        let r = ApplyPlanBuilder.build(candidates: [timed, untimed], requestId: "r", themeKey: nil, mode: .event)
        XCTAssertEqual(r.entries.map(\.candidateId), ["t"])
        XCTAssertEqual(r.skippedNoTimeIds, ["u"])
    }

    func testEventModeRejectsEndBeforeStart() {
        let bad = TimeItemCandidate(id: "b", title: "倒轉", startAt: date(10), endAt: date(9))
        let r = ApplyPlanBuilder.build(candidates: [bad], requestId: "r", themeKey: nil, mode: .event)
        XCTAssertTrue(r.entries.isEmpty)
        XCTAssertEqual(r.skippedNoTimeIds, ["b"])
    }

    func testSuggestionModeKeepsUntimedAsTask() {
        let untimed = TimeItemCandidate(id: "u", title: "沒時間", durationMin: 45)
        let r = ApplyPlanBuilder.build(candidates: [untimed], requestId: "r", themeKey: "k", mode: .suggestion)
        XCTAssertTrue(r.skippedNoTimeIds.isEmpty)
        XCTAssertEqual(r.entries.count, 1)
        let item = r.entries[0].item
        XCTAssertEqual(item.type, .task)
        XCTAssertFalse(item.hasStartAt)
        XCTAssertEqual(item.durationMin, 45)
        XCTAssertEqual(item.requestId, "r")
    }

    // MARK: - 來源關聯（已安排 ≠ 已完成）

    func testEventCarriesLinkedTaskIdFromSourceItemId() {
        let c = TimeItemCandidate(id: "task-1", title: "待辦", startAt: date(9), endAt: date(10), sourceItemId: "task-1")
        let r = ApplyPlanBuilder.build(candidates: [c], requestId: "r", themeKey: nil, mode: .event)
        XCTAssertEqual(r.entries[0].item.linkedTaskId, "task-1")
        XCTAssertEqual(r.entries[0].sourceItemId, "task-1")
        XCTAssertEqual(r.entries[0].item.status, .active)
        XCTAssertNotEqual(r.entries[0].item.id, "task-1", "事件不可覆蓋來源待辦文件")
    }

    // MARK: - ApplyOutcome 摘要

    func testOutcomeSummaryPartial() {
        var o = ApplyOutcome(requestId: "r")
        o.appliedCandidateIds = ["a", "b"]
        o.skippedNoTimeIds = ["c", "d", "e"]
        XCTAssertTrue(o.hasAnyApplied)
        XCTAssertFalse(o.isFullSuccess)
        XCTAssertEqual(o.summaryText, "已加入 2 項；3 項因無可用時間保留待安排")
    }

    func testOutcomeSummaryNothingApplied() {
        var o = ApplyOutcome(requestId: "r")
        o.skippedNoTimeIds = ["c"]
        XCTAssertFalse(o.hasAnyApplied)
        XCTAssertEqual(o.summaryText, "1 項因無可用時間保留待安排")
    }

    // MARK: - 預覽編輯 → 重建 candidates（時間跟著 planDays）

    func testNormalizeReflectsEditedBlockTime() {
        var block = TimeBlock(type: .activity, startTime: date(10), endTime: date(11), title: "A")
        var plan = PlanResult(days: [DayPlan(date: date(0), blocks: [block])], assumptions: [], riskFlags: [])
        let before = GenerationNormalizer.shared.normalize(plan: plan)
        XCTAssertEqual(before[0].startAt, date(10))

        block.startTime = date(11); block.endTime = date(12)
        plan.days[0].blocks[0] = block
        let after = GenerationNormalizer.shared.normalize(plan: plan)
        XCTAssertEqual(after[0].id, before[0].id, "同一 block 編輯後 candidate id 不變（重試去重）")
        XCTAssertEqual(after[0].startAt, date(11))
        XCTAssertEqual(after[0].endAt, date(12))
    }

    func testConflictRecomputedAfterEdit() {
        let existing = TimeItem.event(title: "既有", startAt: date(10), endAt: date(11))
        let before = TimeItemCandidate(id: "c", title: "新", startAt: date(10, 30), endAt: date(11, 30))
        XCTAssertEqual(ConflictDetector.shared.detect(candidates: [before], existingItems: [existing]).count, 1)
        var after = before
        after.startAt = date(11); after.endAt = date(12)
        XCTAssertEqual(ConflictDetector.shared.detect(candidates: [after], existingItems: [existing]).count, 0)
    }
}
