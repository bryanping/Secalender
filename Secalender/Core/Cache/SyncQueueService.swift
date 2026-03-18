//
//  SyncQueueService.swift
//  Secalender
//
//  同步佇列：持久化待同步項目，於 App 啟動/回前台/網路恢復時觸發同步（Local First V1）
//

import Foundation
import FirebaseAuth

/// 管理同步佇列：儲存、讀取、重試間隔，並在適當時機由 EventManager 等消費
final class SyncQueueService {
    static let shared = SyncQueueService()
    private init() {}

    private let userDefaults = UserDefaults.standard
    private let queueKeyPrefix = "sync_queue_"
    private let maxRetries = 5

    // MARK: - 佇列存取

    private func queueKey(userId: String) -> String {
        "\(queueKeyPrefix)\(userId)"
    }

    /// 取得當前使用者的待同步項目（依順序：pendingDelete → pendingCreate → pendingUpdate）
    func getPendingItems(userId: String) -> [SyncQueueItem] {
        guard let data = userDefaults.data(forKey: queueKey(userId: userId)) else { return [] }
        return (try? JSONDecoder().decode([SyncQueueItem].self, from: data)) ?? []
    }

    /// 取得可立即重試的項目（已到 nextRetryAt 或 retryCount == 0）
    func getItemsReadyToSync(userId: String) -> [SyncQueueItem] {
        getPendingItems(userId: userId)
            .filter { $0.shouldRetryNow && $0.retryCount < maxRetries }
            .sorted { a, b in
                // 順序：delete → create → update
                let order: [SyncQueueActionType: Int] = [.delete: 0, .create: 1, .update: 2]
                return (order[a.actionType] ?? 3) < (order[b.actionType] ?? 3)
            }
    }

    /// 加入一筆待同步項目
    func enqueue(_ item: SyncQueueItem) {
        var items = getPendingItems(userId: item.userId)
        items.removeAll { $0.id == item.id }
        items.append(item)
        save(items, userId: item.userId)
    }

    /// 移除已同步成功的項目
    func remove(itemId: String, userId: String) {
        var items = getPendingItems(userId: userId)
        items.removeAll { $0.id == itemId }
        save(items, userId: userId)
    }

    /// 標記失敗並排定下次重試
    func markFailed(itemId: String, userId: String, error: String) {
        var items = getPendingItems(userId: userId)
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].retryCount += 1
        items[index].lastError = error
        let delay = SyncRetryIntervals.nextRetryDelay(retryCount: items[index].retryCount)
        items[index].nextRetryAt = Date().addingTimeInterval(delay)
        save(items, userId: userId)
    }

    /// 取得當前使用者 ID（未登入則為空）
    func currentUserId() -> String? {
        Auth.auth().currentUser?.uid
    }

    /// 觸發同步（由 App 啟動/回前台/手動刷新呼叫，實際執行由 EventManager 等負責）
    func triggerSyncIfNeeded() {
        guard let userId = currentUserId() else { return }
        let ready = getItemsReadyToSync(userId: userId)
        guard !ready.isEmpty else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("SyncQueueNeedsSync"),
            object: nil,
            userInfo: ["userId": userId]
        )
    }

    // MARK: - Private

    private func save(_ items: [SyncQueueItem], userId: String) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        userDefaults.set(data, forKey: queueKey(userId: userId))
    }
}
