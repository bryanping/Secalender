//
//  SchedulerService.swift
//  Secalender
//
//  AI 時間優化引擎 MVP：Auto Fill 塞空檔、一鍵套用、衝突避免
//  輸入：固定事件、浮動任務、可用時間
//  輸出：建議時間段（TimeItem type=suggestion）
//

import Foundation

/// 空檔時段（可用於塞入任務）
struct TimeSlot: Equatable {
    let start: Date
    let end: Date
    var durationMin: Int { max(1, Int(end.timeIntervalSince(start) / 60)) }
}

final class SchedulerService {
    static let shared = SchedulerService()
    private let timeItemService = TimeItemService.shared
    private let minSlotMinutes = 15  // 小於 15 分鐘的空檔不使用
    
    private init() {}
    
    /// 計算空檔：排除 event/block，排除 suggestion
    func computeGaps(rangeStart: Date, rangeEnd: Date, fixedItems: [TimeItem]) -> [TimeSlot] {
        var blocked: [(Date, Date)] = fixedItems.compactMap { item in
            guard let s = item.startAt, let e = item.endAt else { return nil }
            return (s, e)
        }
        blocked.sort { $0.0 < $1.0 }
        
        var gaps: [TimeSlot] = []
        var cursor = rangeStart
        
        for (s, e) in blocked {
            if cursor < s {
                let slot = TimeSlot(start: cursor, end: min(s, rangeEnd))
                if slot.durationMin >= minSlotMinutes {
                    gaps.append(slot)
                }
            }
            if e > cursor { cursor = e }
            if cursor >= rangeEnd { break }
        }
        
        if cursor < rangeEnd {
            let slot = TimeSlot(start: cursor, end: rangeEnd)
            if slot.durationMin >= minSlotMinutes {
                gaps.append(slot)
            }
        }
        
        return gaps
    }
    
    /// 排序任務：deadline 最近優先、priority 高優先、duration 大任務優先分配大空檔
    private func sortTasksForScheduling(_ tasks: [TimeItem]) -> [TimeItem] {
        tasks.sorted { a, b in
            let aDeadline = a.deadlineAt ?? .distantFuture
            let bDeadline = b.deadlineAt ?? .distantFuture
            if aDeadline != bDeadline { return aDeadline < bDeadline }
            let aP = a.priority ?? 3
            let bP = b.priority ?? 3
            if aP != bP { return aP > bP }
            return (a.resolvedDurationMin) >= (b.resolvedDurationMin)
        }
    }
    
    /// Auto Fill：將浮動任務塞入空檔，產生 suggestions
    func autoFill(rangeStart: Date, rangeEnd: Date) async throws -> [TimeItem] {
        let fixedItems = try await timeItemService.fetchFixedItems(rangeStart: rangeStart, rangeEnd: rangeEnd)
        let tasks = try await timeItemService.fetchFloatingTasks()
        let gaps = computeGaps(rangeStart: rangeStart, rangeEnd: rangeEnd, fixedItems: fixedItems)
        
        let sortedTasks = sortTasksForScheduling(tasks)
        var suggestions: [TimeItem] = []
        var usedGaps: [(Int, Date, Date)] = []  // (gapIndex, usedStart, usedEnd)
        
        for task in sortedTasks {
            let duration = task.resolvedDurationMin
            for (idx, gap) in gaps.enumerated() {
                guard gap.durationMin >= duration else { continue }
                
                // 檢查此 gap 是否已被部分使用
                let usedInGap = usedGaps.filter { $0.0 == idx }.sorted { $0.1 < $1.1 }
                var candidateStart = gap.start
                
                if usedInGap.isEmpty {
                    candidateStart = gap.start
                } else {
                    for (_, usedS, usedE) in usedInGap {
                        if candidateStart < usedE && candidateStart.addingTimeInterval(TimeInterval(duration * 60)) > usedS {
                            candidateStart = usedE
                        }
                    }
                    let candidateEnd = candidateStart.addingTimeInterval(TimeInterval(duration * 60))
                    if candidateEnd > gap.end { continue }
                }
                
                let candidateEnd = candidateStart.addingTimeInterval(TimeInterval(duration * 60))
                if candidateEnd <= gap.end {
                    let suggestion = TimeItem.suggestion(
                        title: task.title,
                        startAt: candidateStart,
                        endAt: candidateEnd,
                        linkedTaskId: task.id,
                        notes: task.notes,
                        themeKey: task.themeKey
                    )
                    suggestions.append(suggestion)
                    usedGaps.append((idx, candidateStart, candidateEnd))
                    break
                }
            }
        }
        
        return suggestions
    }
    
    /// 一鍵套用：將 suggestions 寫入 time_items（type=event），並將關聯 task 標記 done
    func applySuggestions(_ suggestions: [TimeItem]) async throws {
        for var s in suggestions {
            var eventItem = s
            eventItem.type = .event
            eventItem.source = .user
            eventItem.linkedTaskId = nil
            _ = try await timeItemService.upsert(eventItem)
        }
        
        for s in suggestions {
            guard let taskId = s.linkedTaskId else { continue }
            guard var task = try await timeItemService.fetchById(taskId) else { continue }
            task.status = .done
            _ = try await timeItemService.upsert(task)
        }
    }
}
