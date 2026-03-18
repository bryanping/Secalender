//
//  GenerateRequest.swift
//  Secalender
//
//  生成引擎統一輸入：各入口頁（AIPlannerView 等）只組此結構，不直接呼叫 AI。
//  分為：基礎欄位（所有模型共用）+ 模型專屬欄位（依 plannerModelType 填寫）。
//

import Foundation
import CoreLocation

// PlannerModelType 已拆至 Models/Planning/PlannerModelType.swift

/// 生成模式（引擎內部與後端對應，由 plannerModelType 推導）
enum GenerateMode: String, Codable, CaseIterable {
    case singleDay = "singleDay"
    case multiDay = "multiDay"
    case taskBreakdown = "taskBreakdown"
}

/// 任務拆解專屬參數
struct TaskBreakdownParams {
    var deadline: Date?
    var availableHoursPerDay: Double?
    var priorityStrategy: String?
    var taskComplexity: String?
}

/// 生成請求：唯一輸入型別（基礎 + 模型專屬）
struct GenerateRequest {
    // MARK: - 基礎欄位（所有模型共用）
    var plannerModelType: PlannerModelType = .multiPhase
    var generateMode: GenerateMode
    var themeKey: String?
    var themeMode: ThemeMode
    var userId: String?
    var title: String? = nil
    var description: String? = nil
    var startDate: Date? = nil
    var endDate: Date? = nil
    var location: String? = nil
    var preferences: [String]? = nil
    var constraints: [String]? = nil
    var timezone: TimeZone? = nil
    var sourcePage: String? = nil
    
    // MARK: - 行程/主題用（slots + 現有欄位，與引擎相容）
    var slots: ExtractedSlots
    var assumptions: [String]
    var riskFlags: [String]
    var npi: NormalizedPlanningInput?
    var customInstructions: String?
    var departureLocation: CLLocation?
    var accommodationAddress: String?
    var accommodationCoordinate: CLLocationCoordinate2D?
    var selectedAttractionNames: [String]
    var customSurroundingTags: [String]
    var adults: Int
    var children: Int
    
    // MARK: - 模型專屬（任務拆解等）
    var taskBreakdown: TaskBreakdownParams? = nil
    
    /// 由 plannerModelType 推導 generateMode
    static func deriveGenerateMode(from modelType: PlannerModelType) -> GenerateMode {
        switch modelType {
        case .multiPhase: return .multiDay
        case .floatingTask: return .taskBreakdown
        case .availability, .recurring, .matching, .aiOptimization, .availabilityCoordination: return .multiDay
        }
    }
}
