//
//  SyncTypes.swift
//  Secalender
//
//  離線同步：同步狀態與佇列項目類型（對應 OFFLINE_SYNC_DESIGN.md）
//

import Foundation

// MARK: - SyncStatus

/// 可同步實體的同步狀態
enum SyncStatus: String, Codable, CaseIterable {
    case synced           // 已與雲端一致
    case pendingCreate    // 待上傳（新增）
    case pendingUpdate    // 待上傳（更新）
    case pendingDelete    // 待上傳（軟刪除）
    case conflicted       // 衝突待使用者處理
    case failed           // 同步失敗，停止自動重試
}

// MARK: - SyncQueueActionType

enum SyncQueueActionType: String, Codable {
    case create
    case update
    case delete
}

// MARK: - SyncQueueEntityType

enum SyncQueueEntityType: String, Codable {
    case event
    case timeItem
    // 之後可擴充：friend, template, ...
}

// MARK: - SyncQueueItem

/// 同步佇列項目：本地待上傳的變更
struct SyncQueueItem: Identifiable, Codable, Equatable {
    var id: String
    var entityType: SyncQueueEntityType
    var entityId: String
    var actionType: SyncQueueActionType
    var payloadSnapshot: Data?
    var retryCount: Int
    var nextRetryAt: Date?
    var createdAt: Date
    var lastError: String?
    var userId: String

    init(
        id: String = UUID().uuidString,
        entityType: SyncQueueEntityType,
        entityId: String,
        actionType: SyncQueueActionType,
        payloadSnapshot: Data? = nil,
        retryCount: Int = 0,
        nextRetryAt: Date? = nil,
        createdAt: Date = Date(),
        lastError: String? = nil,
        userId: String
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.actionType = actionType
        self.payloadSnapshot = payloadSnapshot
        self.retryCount = retryCount
        self.nextRetryAt = nextRetryAt
        self.createdAt = createdAt
        self.lastError = lastError
        self.userId = userId
    }

    /// 是否應在現在重試（已到 nextRetryAt 或尚未設定）
    var shouldRetryNow: Bool {
        guard let at = nextRetryAt else { return true }
        return Date() >= at
    }
}

// MARK: - 重試間隔（秒）

enum SyncRetryIntervals {
    static let delays: [Int] = [0, 10, 30, 120, 600] // 立即、10s、30s、2min、10min
    static func nextRetryDelay(retryCount: Int) -> TimeInterval {
        let index = min(retryCount, delays.count - 1)
        return TimeInterval(delays[index])
    }
}
