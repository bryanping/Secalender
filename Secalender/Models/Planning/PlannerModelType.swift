//
//  PlannerModelType.swift
//  Secalender
//
//  規劃模型類型（時間秘書 / AIPlanner 意圖與表單）
//

import Foundation

enum PlannerModelType: String, Codable, CaseIterable {
    case availability = "availability"
    case floatingTask = "floatingTask"
    case multiPhase = "multiPhase"
    case recurring = "recurring"
    case matching = "matching"
    case aiOptimization = "aiOptimization"
    case availabilityCoordination = "availabilityCoordination"

    var displayTitle: String {
        switch self {
        case .availability: return "區間可選型"
        case .floatingTask: return "彈性任務型"
        case .multiPhase: return "多階段型"
        case .recurring: return "反覆週期型"
        case .matching: return "協作撮合型"
        case .aiOptimization: return "自動優化型"
        case .availabilityCoordination: return "多人時間協調"
        }
    }

    var subtitle: String {
        switch self {
        case .availability: return "可用時間區間 · 他人決定最終時間"
        case .floatingTask: return "deadline / priority · AI 可塞空檔"
        case .multiPhase: return "itinerary / PlanResult · 旅行 / 專案流程"
        case .recurring: return "RRULE · 每週家教 / 每月保養"
        case .matching: return "雙方/多方 · 條件匹配"
        case .aiOptimization: return "系統主動安排 · 高級訂閱"
        case .availabilityCoordination: return "收集空檔 · 交集找時段"
        }
    }

    var iconName: String {
        switch self {
        case .availability: return "calendar.badge.clock"
        case .floatingTask: return "checklist"
        case .multiPhase: return "map.fill"
        case .recurring: return "repeat"
        case .matching: return "person.2.fill"
        case .aiOptimization: return "sparkles"
        case .availabilityCoordination: return "person.3.sequence"
        }
    }
}
