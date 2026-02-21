//
//  CreatorFollowManager.swift
//  Secalender
//
//  博主關注管理：追蹤用戶已關注的創作者
//

import Foundation

/// 創作者關注管理器
final class CreatorFollowManager {
    static let shared = CreatorFollowManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private func key(for userId: String) -> String { "followed_creators_\(userId)" }
    
    /// 關注創作者
    func follow(creatorId: String, for userId: String) {
        var ids = loadFollowedIds(for: userId)
        if !ids.contains(creatorId) {
            ids.append(creatorId)
            saveFollowedIds(ids, for: userId)
        }
    }
    
    /// 取消關注
    func unfollow(creatorId: String, for userId: String) {
        var ids = loadFollowedIds(for: userId)
        ids.removeAll { $0 == creatorId }
        saveFollowedIds(ids, for: userId)
    }
    
    /// 是否已關注
    func isFollowing(creatorId: String, for userId: String) -> Bool {
        loadFollowedIds(for: userId).contains(creatorId)
    }
    
    /// 取得已關注的創作者 ID 列表
    func followedCreatorIds(for userId: String) -> [String] {
        loadFollowedIds(for: userId)
    }
    
    private func loadFollowedIds(for userId: String) -> [String] {
        userDefaults.stringArray(forKey: key(for: userId)) ?? []
    }
    
    private func saveFollowedIds(_ ids: [String], for userId: String) {
        userDefaults.set(ids, forKey: key(for: userId))
    }
}
