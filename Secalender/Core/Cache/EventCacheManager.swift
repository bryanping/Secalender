//
//  EventCacheManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation

// MARK: - 修改内容：Step10 — 事件 id ↔ Firestore 文件路徑索引
/// 事件 id 多由 documentID 雜湊而來，文件本身沒有 `id` 欄位，
/// 因此刪除／更新不能靠 whereField("id") 查詢（永遠查不到，導致「刪不掉」）。
/// 解析文件時記錄路徑，刪除時直接以路徑操作。
final class EventDocumentIndex {
    static let shared = EventDocumentIndex()
    private init() {}

    private let storageKey = "event_document_paths"
    private let userDefaults = UserDefaults.standard
    private var memoryMap: [String: String]?

    private var map: [String: String] {
        get {
            if let cached = memoryMap { return cached }
            let stored = (userDefaults.dictionary(forKey: storageKey) as? [String: String]) ?? [:]
            memoryMap = stored
            return stored
        }
        set {
            memoryMap = newValue
            userDefaults.set(newValue, forKey: storageKey)
        }
    }

    /// 記錄事件對應的 Firestore 文件路徑
    func record(eventId: Int?, path: String) {
        guard let eventId, !path.isEmpty else { return }
        var current = map
        guard current[String(eventId)] != path else { return }
        current[String(eventId)] = path
        map = current
    }

    func path(for eventId: Int) -> String? {
        map[String(eventId)]
    }

    func remove(eventId: Int) {
        var current = map
        guard current.removeValue(forKey: String(eventId)) != nil else { return }
        map = current
    }
}

// MARK: - 修改内容：Step11 — 刪除墓碑（離線也能「刪得掉」）
/// 離線或連線逾時時，刪除只作用於本地，下次同步又被雲端資料還原。
/// 這裡記錄「已刪除但尚未被伺服器確認」的事件，載入時一律過濾，
/// 待 Firestore 送出刪除成功後才清除紀錄。
final class DeletedEventRegistry {
    static let shared = DeletedEventRegistry()
    private init() {}

    struct Tombstone: Codable {
        let eventId: Int
        var path: String?
        var timeItemId: String?
        let createdAt: Date
        /// 只在本機隱藏，不刪除雲端來源（他人分享、無權限刪除者）
        var hideOnly: Bool?
        // 修改内容：Step15 — 刪除歷史顯示用
        var title: String?
        var date: String?
    }

    private let userDefaults = UserDefaults.standard
    private let storageKey = "deleted_event_tombstones"
    /// 保留上限：超過此期間仍未確認即視為已完成，避免無限成長
    private let maxAge: TimeInterval = 30 * 24 * 60 * 60

    private func key(_ userId: String) -> String { "\(storageKey)_\(userId)" }

    func tombstones(for userId: String) -> [Tombstone] {
        guard let data = userDefaults.data(forKey: key(userId)),
              let list = try? JSONDecoder().decode([Tombstone].self, from: data) else { return [] }
        let now = Date()
        return list.filter { now.timeIntervalSince($0.createdAt) < maxAge }
    }

    private func save(_ list: [Tombstone], for userId: String) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        userDefaults.set(data, forKey: key(userId))
    }

    func mark(eventId: Int, path: String?, timeItemId: String?, for userId: String,
              hideOnly: Bool = false, title: String? = nil, date: String? = nil) {
        guard !userId.isEmpty else { return }
        var list = tombstones(for: userId).filter { $0.eventId != eventId }
        list.append(Tombstone(eventId: eventId, path: path, timeItemId: timeItemId,
                              createdAt: Date(), hideOnly: hideOnly, title: title, date: date))
        save(list, for: userId)
    }

    /// 刪除歷史（新到舊）
    func history(for userId: String) -> [Tombstone] {
        tombstones(for: userId).sorted { $0.createdAt > $1.createdAt }
    }

    /// 清空刪除歷史（不會恢復已刪除的資料）
    func clearHistory(for userId: String) {
        save([], for: userId)
    }

    func clear(eventId: Int, for userId: String) {
        guard !userId.isEmpty else { return }
        save(tombstones(for: userId).filter { $0.eventId != eventId }, for: userId)
    }

    func isDeleted(_ eventId: Int?, for userId: String) -> Bool {
        guard let eventId, !userId.isEmpty else { return false }
        return tombstones(for: userId).contains { $0.eventId == eventId }
    }

    /// 過濾掉已刪除（待確認）的事件
    func filterDeleted(_ events: [Event], for userId: String) -> [Event] {
        let deletedIds = Set(tombstones(for: userId).map { $0.eventId })
        let deletedItemIds = Set(tombstones(for: userId).compactMap { $0.timeItemId })
        guard !deletedIds.isEmpty || !deletedItemIds.isEmpty else { return events }
        return events.filter { event in
            if let id = event.id, deletedIds.contains(id) { return false }
            if let itemId = event.timeItemId, deletedItemIds.contains(itemId) { return false }
            return true
        }
    }
}

/// 事件缓存管理器 - 用于本地存储事件数据
final class EventCacheManager {
    static let shared = EventCacheManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let eventsCacheKey = "cached_events"
    private let groupsCacheKey = "cached_group_ids"
    private let cacheTimestampKey = "events_cache_timestamp"
    private let cacheVersionKey = "events_cache_version"
    private let currentCacheVersion = 1
    
    // MARK: - 缓存事件列表
    
    /// 保存事件列表到本地缓存
    func saveEvents(_ events: [Event], for userId: String, groupIds: Set<String>? = nil) {
        let cacheKey = "\(eventsCacheKey)_\(userId)"
        let timestampKey = "\(cacheTimestampKey)_\(userId)"
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(events)
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date(), forKey: timestampKey)
            userDefaults.set(currentCacheVersion, forKey: "\(cacheVersionKey)_\(userId)")
            print("✅ 事件缓存已保存: \(events.count) 个事件")
            
            if let ids = groupIds {
                saveGroupIds(ids, for: userId)
            }
        } catch {
            print("❌ 保存事件缓存失败: \(error.localizedDescription)")
        }
    }
    
    /// 保存用户加入的社群 ID 列表（与事件缓存共用时间戳，用于 cache-first 时跳过 Firestore）
    func saveGroupIds(_ groupIds: Set<String>, for userId: String) {
        let cacheKey = "\(groupsCacheKey)_\(userId)"
        userDefaults.set(Array(groupIds), forKey: cacheKey)
    }
    
    /// 从缓存加载社群 ID 列表
    func loadGroupIds(for userId: String) -> Set<String> {
        let cacheKey = "\(groupsCacheKey)_\(userId)"
        guard let array = userDefaults.stringArray(forKey: cacheKey) else {
            return []
        }
        return Set(array)
    }
    
    /// 从本地缓存加载事件列表
    func loadEvents(for userId: String) -> [Event] {
        let cacheKey = "\(eventsCacheKey)_\(userId)"
        
        guard let data = userDefaults.data(forKey: cacheKey) else {
            print("📭 本地缓存为空")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let events = try decoder.decode([Event].self, from: data)
            print("✅ 从本地缓存加载了 \(events.count) 个事件")
            return events
        } catch {
            print("❌ 读取事件缓存失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取缓存时间戳
    func getCacheTimestamp(for userId: String) -> Date? {
        let timestampKey = "\(cacheTimestampKey)_\(userId)"
        return userDefaults.object(forKey: timestampKey) as? Date
    }
    
    /// 检查缓存是否有效（例如：24小时内有效）
    func isCacheValid(for userId: String, maxAge: TimeInterval = 24 * 60 * 60) -> Bool {
        guard let timestamp = getCacheTimestamp(for: userId) else {
            return false
        }
        let age = Date().timeIntervalSince(timestamp)
        return age < maxAge
    }
    
    /// 添加单个事件到缓存
    func addEventToCache(_ event: Event, for userId: String) {
        var cachedEvents = loadEvents(for: userId)
        
        // 如果事件已存在（通过 id 判断），更新它
        if let eventId = event.id {
            if let index = cachedEvents.firstIndex(where: { $0.id == eventId }) {
                // 更新现有事件
                cachedEvents[index] = event
            } else {
                // 检查是否有相同内容但没有 id 的临时事件（可能是之前添加的）
                if let tempIndex = cachedEvents.firstIndex(where: { cachedEvent in
                    cachedEvent.id == nil &&
                    cachedEvent.title == event.title &&
                    cachedEvent.date == event.date &&
                    cachedEvent.startTime == event.startTime &&
                    cachedEvent.creatorOpenid == event.creatorOpenid
                }) {
                    // 用有 id 的事件替换临时事件
                    cachedEvents[tempIndex] = event
                } else {
                    // 直接添加新事件
                    cachedEvents.append(event)
                }
            }
        } else {
            // 如果没有 id，通过其他唯一标识判断是否重复（title + date + startTime + creatorOpenid + createTime）
            let isDuplicate = cachedEvents.contains { cachedEvent in
                cachedEvent.title == event.title &&
                cachedEvent.date == event.date &&
                cachedEvent.startTime == event.startTime &&
                cachedEvent.creatorOpenid == event.creatorOpenid &&
                (cachedEvent.id == nil || cachedEvent.createTime == event.createTime) // 检查没有 id 的或创建时间相同的
            }
            
            if !isDuplicate {
                cachedEvents.append(event)
            } else {
                // 如果是重复的，更新现有的事件
                if let index = cachedEvents.firstIndex(where: { cachedEvent in
                    cachedEvent.title == event.title &&
                    cachedEvent.date == event.date &&
                    cachedEvent.startTime == event.startTime &&
                    cachedEvent.creatorOpenid == event.creatorOpenid &&
                    (cachedEvent.id == nil || cachedEvent.createTime == event.createTime)
                }) {
                    // 如果现有事件有 id，保留 id；否则更新为新事件
                    if cachedEvents[index].id != nil {
                        // 保留原有 id，更新内容（包括 groupId，确保社群行程的 groupId 被正确更新）
                        var updatedEvent = cachedEvents[index]
                        updatedEvent.information = event.information
                        updatedEvent.destination = event.destination
                        updatedEvent.endTime = event.endTime
                        updatedEvent.endDate = event.endDate
                        updatedEvent.groupId = event.groupId  // 确保 groupId 被更新
                        cachedEvents[index] = updatedEvent
                    } else {
                        // 替换为新事件
                        cachedEvents[index] = event
                    }
                }
            }
        }
        
        saveEvents(cachedEvents, for: userId)
    }
    
    /// 更新缓存中的事件
    func updateEventInCache(_ event: Event, for userId: String) {
        var cachedEvents = loadEvents(for: userId)
        
        if let index = cachedEvents.firstIndex(where: { $0.id == event.id }) {
            cachedEvents[index] = event
            saveEvents(cachedEvents, for: userId)
        }
    }
    
    /// 从缓存中删除事件
    func removeEventFromCache(eventId: Int, for userId: String) {
        var cachedEvents = loadEvents(for: userId)
        cachedEvents.removeAll { $0.id == eventId }
        saveEvents(cachedEvents, for: userId)
    }
    
    /// 清除指定用户的缓存
    func clearCache(for userId: String) {
        let cacheKey = "\(eventsCacheKey)_\(userId)"
        let groupsKey = "\(groupsCacheKey)_\(userId)"
        let timestampKey = "\(cacheTimestampKey)_\(userId)"
        let versionKey = "\(cacheVersionKey)_\(userId)"
        
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: groupsKey)
        userDefaults.removeObject(forKey: timestampKey)
        userDefaults.removeObject(forKey: versionKey)
        
        print("🗑️ 已清除用户 \(userId) 的事件缓存")
    }
    
    /// 清除所有缓存
    func clearAllCache() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix(eventsCacheKey) || key.hasPrefix(groupsCacheKey) || key.hasPrefix(cacheTimestampKey) || key.hasPrefix(cacheVersionKey) {
                userDefaults.removeObject(forKey: key)
            }
        }
        print("🗑️ 已清除所有事件缓存")
    }
    
    /// 获取缓存大小（字节）
    func getCacheSize(for userId: String) -> Int64 {
        let cacheKey = "\(eventsCacheKey)_\(userId)"
        guard let data = userDefaults.data(forKey: cacheKey) else {
            return 0
        }
        return Int64(data.count)
    }
}
