//
//  TimeItemCandidate.swift
//  Secalender
//
//  生成候選項：Normalizer 產出，供 Classifier / ConflictDetector / ApplyStrategy 使用。
//

import Foundation

/// 候選項類型（對應活動/交通/任務等）
enum TimeItemCandidateType: String, Codable {
    case activity
    case transit
    case task
    case rest
    case flex
}

/// 單一候選項（可有時間或僅 duration）
struct TimeItemCandidate: Identifiable, Equatable {
    var id: String
    var title: String
    var notes: String?
    var startAt: Date?
    var endAt: Date?
    var durationMin: Int?
    var type: TimeItemCandidateType
    var location: String?
    var dayIndex: Int
    var sourceBlockId: UUID?

    var hasTime: Bool {
        startAt != nil && endAt != nil
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        startAt: Date? = nil,
        endAt: Date? = nil,
        durationMin: Int? = nil,
        type: TimeItemCandidateType = .activity,
        location: String? = nil,
        dayIndex: Int = 0,
        sourceBlockId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.startAt = startAt
        self.endAt = endAt
        self.durationMin = durationMin
        self.type = type
        self.location = location
        self.dayIndex = dayIndex
        self.sourceBlockId = sourceBlockId
    }
}
