//
//  FriendCacheManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation

/// 朋友名单缓存管理器 - 用于本地存储朋友名单数据（参考微信做法）
final class FriendCacheManager {
    static let shared = FriendCacheManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let friendsCacheKey = "cached_friends"
    private let cacheTimestampKey = "friends_cache_timestamp"
    private let cacheVersionKey = "friends_cache_version"
    private let currentCacheVersion = 1
    
    // MARK: - 缓存朋友名单
    
    /// 保存朋友名单到本地缓存
    func saveFriends(_ friends: [FriendEntry], for userId: String) {
        let cacheKey = "\(friendsCacheKey)_\(userId)"
        let timestampKey = "\(cacheTimestampKey)_\(userId)"
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(friends)
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date(), forKey: timestampKey)
            userDefaults.set(currentCacheVersion, forKey: "\(cacheVersionKey)_\(userId)")
            print("✅ 朋友名单缓存已保存: \(friends.count) 个朋友")
        } catch {
            print("❌ 保存朋友名单缓存失败: \(error.localizedDescription)")
        }
    }
    
    /// 从本地缓存加载朋友名单
    func loadFriends(for userId: String) -> [FriendEntry] {
        let cacheKey = "\(friendsCacheKey)_\(userId)"
        
        guard let data = userDefaults.data(forKey: cacheKey) else {
            print("📭 本地朋友名单缓存为空")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let friends = try decoder.decode([FriendEntry].self, from: data)
            print("✅ 从本地缓存加载了 \(friends.count) 个朋友")
            return friends
        } catch {
            print("❌ 读取朋友名单缓存失败: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 获取缓存时间戳
    func getCacheTimestamp(for userId: String) -> Date? {
        let timestampKey = "\(cacheTimestampKey)_\(userId)"
        return userDefaults.object(forKey: timestampKey) as? Date
    }
    
    /// 检查缓存是否有效（默认24小时内有效）
    func isCacheValid(for userId: String, maxAge: TimeInterval = 24 * 60 * 60) -> Bool {
        guard let timestamp = getCacheTimestamp(for: userId) else {
            return false
        }
        let age = Date().timeIntervalSince(timestamp)
        return age < maxAge
    }
    
    /// 添加单个朋友到缓存
    func addFriendToCache(_ friend: FriendEntry, for userId: String) {
        var cachedFriends = loadFriends(for: userId)
        
        // 如果朋友已存在，更新它
        if let index = cachedFriends.firstIndex(where: { $0.id == friend.id }) {
            cachedFriends[index] = friend
        } else {
            cachedFriends.append(friend)
        }
        
        saveFriends(cachedFriends, for: userId)
    }
    
    /// 更新缓存中的朋友信息
    func updateFriendInCache(_ friend: FriendEntry, for userId: String) {
        var cachedFriends = loadFriends(for: userId)
        
        if let index = cachedFriends.firstIndex(where: { $0.id == friend.id }) {
            cachedFriends[index] = friend
            saveFriends(cachedFriends, for: userId)
        }
    }
    
    /// 从缓存中删除朋友
    func removeFriendFromCache(friendId: String, for userId: String) {
        var cachedFriends = loadFriends(for: userId)
        cachedFriends.removeAll { $0.id == friendId }
        saveFriends(cachedFriends, for: userId)
    }
    
    /// 清除指定用户的缓存
    func clearCache(for userId: String) {
        let cacheKey = "\(friendsCacheKey)_\(userId)"
        let timestampKey = "\(cacheTimestampKey)_\(userId)"
        let versionKey = "\(cacheVersionKey)_\(userId)"
        
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: timestampKey)
        userDefaults.removeObject(forKey: versionKey)
        
        print("🗑️ 已清除用户 \(userId) 的朋友名单缓存")
    }
    
    /// 清除所有缓存
    func clearAllCache() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix(friendsCacheKey) || key.hasPrefix(cacheTimestampKey) || key.hasPrefix(cacheVersionKey) {
                userDefaults.removeObject(forKey: key)
            }
        }
        print("🗑️ 已清除所有朋友名单缓存")
    }
    
    /// 获取缓存大小（字节）
    func getCacheSize(for userId: String) -> Int64 {
        let cacheKey = "\(friendsCacheKey)_\(userId)"
        guard let data = userDefaults.data(forKey: cacheKey) else {
            return 0
        }
        return Int64(data.count)
    }
}
