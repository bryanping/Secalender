//
//  ContextProvider.swift
//  Secalender
//
//  讀取生成用上下文：time_items 範圍、block / event 等。
//

import Foundation

/// 生成用上下文（供衝突檢測、scheduler 使用）
struct GenerationContext {
    var rangeStart: Date
    var rangeEnd: Date
    var existingItems: [TimeItem]  // event + block
}

final class ContextProvider {
    static let shared = ContextProvider()
    private let timeItemService = TimeItemService.shared
    private init() {}

    /// 依請求的日期範圍取得現有 event/block（優先 slots.dateRange，其次 request.startDate/endDate）
    func fetchContext(for request: GenerateRequest) async throws -> GenerationContext {
        let start: Date
        let end: Date
        if let dateRange = request.slots.dateRange.value {
            start = dateRange.startDate
            end = dateRange.endDate
        } else if let s = request.startDate, let e = request.endDate, e >= s {
            start = s
            end = e
        } else if let deadline = request.taskBreakdown?.deadline {
            let cal = Calendar.current
            start = request.startDate ?? cal.startOfDay(for: Date())
            end = cal.startOfDay(for: deadline).addingTimeInterval(86400 - 1)
        } else {
            let now = Date()
            start = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            end = Calendar.current.date(byAdding: .day, value: 30, to: start) ?? start
        }
        let items = try await timeItemService.fetchFixedItems(rangeStart: start, rangeEnd: end)
        return GenerationContext(rangeStart: start, rangeEnd: end, existingItems: items)
    }
}
