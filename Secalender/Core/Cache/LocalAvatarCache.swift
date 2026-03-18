//
//  LocalAvatarCache.swift
//  Secalender
//
//  頭像本機儲存：當前用戶頭像存到 Caches，減少 Firebase Storage 下載。
//

import Foundation
import UIKit

enum LocalAvatarCache {
    private static let fileManager = FileManager.default
    private static let subdir = "avatars"

    static var cacheDirectory: URL {
        let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(subdir, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func path(forUserId userId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(userId).jpg", isDirectory: false)
    }

    /// 儲存當前用戶頭像圖片資料（上傳成功後或從網路下載後呼叫）
    static func saveAvatar(_ imageData: Data, forUserId userId: String) {
        let url = path(forUserId: userId)
        try? imageData.write(to: url)
    }

    /// 讀取本機頭像；無則回傳 nil（UI 可改為用遠端 URL）
    static func loadAvatar(forUserId userId: String) -> Data? {
        let url = path(forUserId: userId)
        return try? Data(contentsOf: url)
    }

    /// 是否有本機頭像
    static func hasLocalAvatar(forUserId userId: String) -> Bool {
        let url = path(forUserId: userId)
        return fileManager.fileExists(atPath: url.path)
    }

    /// 登出時可清除當前用戶頭像快取
    static func removeAvatar(forUserId userId: String) {
        let url = path(forUserId: userId)
        try? fileManager.removeItem(at: url)
    }
}
