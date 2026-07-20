//
//  TimeOSV1.swift
//  Secalender
//
//  Phase 0 清理:原 TimeOS V1(TimeSecretaryView/TimeAllocationEngine 等)為無入口孤兒碼,已移除。
//  僅保留 AITripGenerator 仍在使用的資料模型 TimePlanDay / TimePlanItem。
//

import Foundation

struct TimePlanDay: Codable, Identifiable {
    let id: String
    let dateLabel: String
    let items: [TimePlanItem]
}

struct TimePlanItem: Codable, Identifiable {
    let id: String
    let title: String
    let startText: String?
    let endText: String?
    let durationMinutes: Int?
    let note: String?
    // 修改内容：支持主线/可选/备选优先级与现实缓冲字段（向后兼容）
    let priority: PlanStopPriority
    let category: String?
    let isOptional: Bool
    let estimatedTransferMinutes: Int?
    let bufferMinutes: Int?

    init(
        id: String = UUID().uuidString,
        title: String,
        startText: String? = nil,
        endText: String? = nil,
        durationMinutes: Int? = nil,
        note: String? = nil,
        priority: PlanStopPriority = .secondary,
        category: String? = nil,
        isOptional: Bool = false,
        estimatedTransferMinutes: Int? = nil,
        bufferMinutes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.startText = startText
        self.endText = endText
        self.durationMinutes = durationMinutes
        self.note = note
        self.priority = priority
        self.category = category
        self.isOptional = isOptional
        self.estimatedTransferMinutes = estimatedTransferMinutes
        self.bufferMinutes = bufferMinutes
    }
}
