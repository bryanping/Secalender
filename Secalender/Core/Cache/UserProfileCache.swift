//
//  UserProfileCache.swift
//  Secalender
//
//  本地快取當前用戶資料，減少 Firestore 讀取次數。
//

import Foundation

/// 可編碼的用戶資料快取結構（不含 Firestore Timestamp）
struct CachedUserProfile: Codable {
    let userId: String
    let alias: String?
    let displayName: String?
    let name: String?
    let gender: String?
    let photoUrl: String?
    let role: String?
    let userCode: String?
    let region: String?
    let phone: String?
    let userCodeModified: Bool?
    let favoriteTags: [String]?
    let signature: String?
    let providerDisplayName: String?
    let hasCustomDisplayName: Bool?
    let phoneVerified: Bool?
    let basicInfoCompleted: Bool?
}

final class UserProfileCache {
    static let shared = UserProfileCache()
    private init() {}

    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "cached_user_profile_"
    private let timestampKeyPrefix = "cached_user_profile_ts_"
    private let maxAge: TimeInterval = 24 * 60 * 60 // 24 小時內可優先使用快取

    func save(_ profile: CachedUserProfile) {
        let key = "\(keyPrefix)\(profile.userId)"
        let tsKey = "\(timestampKeyPrefix)\(profile.userId)"
        do {
            let data = try JSONEncoder().encode(profile)
            userDefaults.set(data, forKey: key)
            userDefaults.set(Date(), forKey: tsKey)
        } catch {
            #if DEBUG
            print("❌ UserProfileCache save error: \(error.localizedDescription)")
            #endif
        }
    }

    func load(userId: String) -> CachedUserProfile? {
        let key = "\(keyPrefix)\(userId)"
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedUserProfile.self, from: data)
    }

    func isCacheValid(userId: String) -> Bool {
        let tsKey = "\(timestampKeyPrefix)\(userId)"
        guard let date = userDefaults.object(forKey: tsKey) as? Date else { return false }
        return Date().timeIntervalSince(date) < maxAge
    }

    func clear(userId: String) {
        userDefaults.removeObject(forKey: "\(keyPrefix)\(userId)")
        userDefaults.removeObject(forKey: "\(timestampKeyPrefix)\(userId)")
    }
}

extension CachedUserProfile {
    static func from(_ dbUser: DBUser) -> CachedUserProfile {
        CachedUserProfile(
            userId: dbUser.userId,
            alias: dbUser.alias,
            displayName: dbUser.displayName,
            name: dbUser.name,
            gender: dbUser.gender,
            photoUrl: dbUser.photoUrl,
            role: dbUser.role,
            userCode: dbUser.userCode,
            region: dbUser.region,
            phone: dbUser.phone,
            userCodeModified: dbUser.userCodeModified,
            favoriteTags: dbUser.favoriteTags,
            signature: dbUser.signature,
            providerDisplayName: dbUser.providerDisplayName,
            hasCustomDisplayName: dbUser.hasCustomDisplayName,
            phoneVerified: dbUser.phoneVerified,
            basicInfoCompleted: dbUser.basicInfoCompleted
        )
    }
}
