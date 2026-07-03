//
//  UserProfileStatsService.swift
//  Secalender
//
//  個人資料統計：從 Firestore 讀取 追蹤中/粉絲/收藏/Saves/Likes、驗證狀態
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// 個人資料頁與頭像區使用的統計（全部來自後端）
struct UserProfileStats {
    var followingCount: Int
    var followersCount: Int
    var favoritesCount: Int
    var savesCount: Int
    var likesCount: Int
    var isVerified: Bool

    static var empty: UserProfileStats {
        UserProfileStats(
            followingCount: 0,
            followersCount: 0,
            favoritesCount: 0,
            savesCount: 0,
            likesCount: 0,
            isVerified: false
        )
    }
}

final class UserProfileStatsService {
    static let shared = UserProfileStatsService()
    private let db = Firestore.firestore()

    private init() {}

    /// 取得指定用戶的資料統計（全部接後端）
    func fetchStats(for userId: String) async -> UserProfileStats {
        guard !userId.isEmpty else { return .empty }

        async let following = fetchFollowingCount(userId: userId)
        async let followers = fetchFollowersCount(userId: userId)
        async let userCounts = fetchUserDocumentCounts(userId: userId)
        async let influence = fetchInfluenceFallback(userId: userId)

        let (followingCount, followersCount, userCountsResult, influenceStats) = await (following, followers, userCounts, influence)

        let favorites = userCountsResult.favorites ?? influenceStats.eventsCreated
        let saves = userCountsResult.saves ?? influenceStats.templatesCreated
        let likes = userCountsResult.likes ?? influenceStats.weeklyEngagement
        let isVerified = userCountsResult.isVerified

        return UserProfileStats(
            followingCount: followingCount,
            followersCount: followersCount,
            favoritesCount: favorites,
            savesCount: saves,
            likesCount: likes,
            isVerified: isVerified
        )
    }

    /// 追蹤中：friends 裡 owner == userId 的數量
    private func fetchFollowingCount(userId: String) async -> Int {
        do {
            let snapshot = try await db.collection("friends")
                .whereField("owner", isEqualTo: userId)
                .getDocuments()
            return snapshot.documents.count
        } catch {
            print("⚠️ UserProfileStats fetchFollowingCount error: \(error.localizedDescription)")
            return 0
        }
    }

    /// 粉絲：friends 裡 friend == userId 的數量
    private func fetchFollowersCount(userId: String) async -> Int {
        do {
            let snapshot = try await db.collection("friends")
                .whereField("friend", isEqualTo: userId)
                .getDocuments()
            return snapshot.documents.count
        } catch {
            print("⚠️ UserProfileStats fetchFollowersCount error: \(error.localizedDescription)")
            return 0
        }
    }

    /// users 文檔可選欄位：favorites_count, saves_count, likes_count, verified
    private func fetchUserDocumentCounts(userId: String) async -> (favorites: Int?, saves: Int?, likes: Int?, isVerified: Bool) {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            guard let data = doc.data() else {
                return (nil, nil, nil, false)
            }
            let favorites = data["favorites_count"] as? Int
            let saves = data["saves_count"] as? Int
            let likes = data["likes_count"] as? Int
            let isVerified = (data["verified"] as? Bool) ?? (data["phone_verified"] as? Bool) ?? false
            return (favorites, saves, likes, isVerified)
        } catch {
            print("⚠️ UserProfileStats fetchUserDocumentCounts error: \(error.localizedDescription)")
            return (nil, nil, nil, false)
        }
    }

    /// 若 users 無計數欄位，用 influence_stats 當 fallback
    private func fetchInfluenceFallback(userId: String) async -> (eventsCreated: Int, templatesCreated: Int, weeklyEngagement: Int) {
        do {
            let doc = try await db.collection("users").document(userId)
                .collection("influence_stats").document("current").getDocument()
            guard let data = doc.data() else {
                return (0, 0, 0)
            }
            let eventsCreated = data["eventsCreated"] as? Int ?? 0
            let templatesCreated = data["templatesCreated"] as? Int ?? 0
            let weeklyEngagement = data["weeklyEngagement"] as? Int ?? 0
            return (eventsCreated, templatesCreated, weeklyEngagement)
        } catch {
            return (0, 0, 0)
        }
    }
}
