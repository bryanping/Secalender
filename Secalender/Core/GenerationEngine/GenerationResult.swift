//
//  GenerationResult.swift
//  Secalender
//
//  生成引擎唯一對外輸出。PlanResult 僅作為過渡兼容欄位存在於 plan。
//

import Foundation

/// 結果型態（用於 UI 顯示與後續流程分支）
enum GenerationResultType: String, Codable {
    case timedPlan = "timedPlan"       // 完整有時間
    case untimedPlan = "untimedPlan"   // 無完整時間
    case taskOnly = "taskOnly"         // 僅任務
    case empty = "empty"
    case partialSuccess = "partialSuccess"
}

/// 單一衝突描述
struct ConflictInfo: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let candidateId: String?
    let existingItemId: String?
    let startAt: Date?
    let endAt: Date?

    init(id: UUID = UUID(), title: String, detail: String, candidateId: String? = nil, existingItemId: String? = nil, startAt: Date? = nil, endAt: Date? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.candidateId = candidateId
        self.existingItemId = existingItemId
        self.startAt = startAt
        self.endAt = endAt
    }
}

/// 生成引擎主輸出
struct GenerationResult: Identifiable, Equatable {
    var id: UUID
    var resultType: GenerationResultType
    /// 過渡兼容：新功能不得以 PlanResult 為主體，僅供現有 PlanDetailView 顯示用
    var plan: PlanResult?
    var candidates: [TimeItemCandidate]
    var conflicts: [ConflictInfo]
    var assumptions: [String]
    var riskFlags: [String]
    var requestId: String?
    /// 寫入 time_items 時帶入 themeKey，便於篩選與統計
    var themeKey: String?

    init(
        id: UUID = UUID(),
        resultType: GenerationResultType,
        plan: PlanResult? = nil,
        candidates: [TimeItemCandidate] = [],
        conflicts: [ConflictInfo] = [],
        assumptions: [String] = [],
        riskFlags: [String] = [],
        requestId: String? = nil,
        themeKey: String? = nil
    ) {
        self.id = id
        self.resultType = resultType
        self.plan = plan
        self.candidates = candidates
        self.conflicts = conflicts
        self.assumptions = assumptions
        self.riskFlags = riskFlags
        self.requestId = requestId
        self.themeKey = themeKey
    }

    static func == (lhs: GenerationResult, rhs: GenerationResult) -> Bool {
        lhs.id == rhs.id
    }
}
