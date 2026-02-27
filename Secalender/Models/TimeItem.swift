//
//  TimeItem.swift
//  Secalender
//
//  統一時間物件：事件、任務、可用時間、保護時間、AI 建議
//  路徑：users/{uid}/time_items/{itemId}
//

import Foundation

// MARK: - TimeItemType

enum TimeItemType: String, Codable, CaseIterable {
    case event = "event"
    case task = "task"
    case availability = "availability"
    case block = "block"
    case suggestion = "suggestion"
    
    var displayName: String {
        switch self {
        case .event: return "event"
        case .task: return "task"
        case .availability: return "availability"
        case .block: return "block"
        case .suggestion: return "suggestion"
        }
    }
}

// MARK: - TimeItemStatus

enum TimeItemStatus: String, Codable, CaseIterable {
    case active = "active"
    case done = "done"
    case canceled = "canceled"
}

// MARK: - TimeItemSource

enum TimeItemSource: String, Codable, CaseIterable {
    case user = "user"
    case ai = "ai"
    case imported = "imported"
    case legacy = "legacy"  // 遷移自舊 events
}

// MARK: - TimeItem

struct TimeItem: Identifiable, Codable, Equatable {
    var id: String?  // Firestore document ID
    var type: TimeItemType
    var title: String
    var notes: String?
    var startAt: Date?
    var endAt: Date?
    /// 必須：避免 Firestore null 查詢問題。event/block/suggestion 有 startAt 則 true，task 無 startAt 則 false
    var hasStartAt: Bool
    var durationMin: Int?
    var deadlineAt: Date?
    var priority: Int?  // 1~5
    var energyTag: String?  // deepWork / light / admin
    var themeKey: String?
    var requestId: String?
    var templateId: String?
    var source: TimeItemSource
    var status: TimeItemStatus
    var createdAt: Date?
    var updatedAt: Date?
    
    /// 關聯的 task id（suggestion 套用後，原 task 標記 done）
    var linkedTaskId: String?
    
    init(
        id: String? = nil,
        type: TimeItemType,
        title: String,
        notes: String? = nil,
        startAt: Date? = nil,
        endAt: Date? = nil,
        hasStartAt: Bool,
        durationMin: Int? = nil,
        deadlineAt: Date? = nil,
        priority: Int? = nil,
        energyTag: String? = nil,
        themeKey: String? = nil,
        requestId: String? = nil,
        templateId: String? = nil,
        source: TimeItemSource = .user,
        status: TimeItemStatus = .active,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        linkedTaskId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.notes = notes
        self.startAt = startAt
        self.endAt = endAt
        self.hasStartAt = hasStartAt
        self.durationMin = durationMin
        self.deadlineAt = deadlineAt
        self.priority = priority
        self.energyTag = energyTag
        self.themeKey = themeKey
        self.requestId = requestId
        self.templateId = templateId
        self.source = source
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedTaskId = linkedTaskId
    }
    
    /// 解析後的 duration（分鐘）：endAt-startAt 或 durationMin
    var resolvedDurationMin: Int {
        if let s = startAt, let e = endAt {
            return max(1, Int(e.timeIntervalSince(s) / 60))
        }
        return durationMin ?? 60
    }
}

// MARK: - 工廠方法

extension TimeItem {
    /// 建立 event 型（有 startAt/endAt）
    static func event(
        title: String,
        startAt: Date,
        endAt: Date,
        notes: String? = nil,
        themeKey: String? = nil,
        source: TimeItemSource = .user
    ) -> TimeItem {
        TimeItem(
            type: .event,
            title: title,
            notes: notes,
            startAt: startAt,
            endAt: endAt,
            hasStartAt: true,
            source: source,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    /// 建立 task 型（無 startAt，有 deadline）
    static func task(
        title: String,
        durationMin: Int,
        deadlineAt: Date? = nil,
        priority: Int? = nil,
        notes: String? = nil,
        themeKey: String? = nil,
        source: TimeItemSource = .user
    ) -> TimeItem {
        TimeItem(
            type: .task,
            title: title,
            notes: notes,
            startAt: nil,
            endAt: nil,
            hasStartAt: false,
            durationMin: durationMin,
            deadlineAt: deadlineAt,
            priority: priority ?? 3,
            themeKey: themeKey,
            source: source,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    /// 建立 suggestion 型（AI 建議）
    static func suggestion(
        title: String,
        startAt: Date,
        endAt: Date,
        linkedTaskId: String? = nil,
        notes: String? = nil,
        themeKey: String? = nil
    ) -> TimeItem {
        TimeItem(
            type: .suggestion,
            title: title,
            notes: notes,
            startAt: startAt,
            endAt: endAt,
            hasStartAt: true,
            themeKey: themeKey,
            source: .ai,
            createdAt: Date(),
            updatedAt: Date(),
            linkedTaskId: linkedTaskId
        )
    }
}
