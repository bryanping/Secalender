//
//  EventCacheManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation

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
