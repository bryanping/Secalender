//
//  ImageCacheService.swift
//  Secalender
//
//  依 URL 快取遠端圖片到本機，減少重複下載（好友/模板頭像等）。
//

import Foundation
import UIKit

enum ImageCacheService {
    private static let fileManager = FileManager.default
    private static let subdir = "image_cache"

    static var cacheDirectory: URL {
        let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(subdir, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func cacheKey(for url: URL) -> String {
        let raw = url.absoluteString
        var hasher = Hasher()
        hasher.combine(raw)
        return "\(hasher.finalize().magnitude)"
    }

    static func path(for url: URL) -> URL {
        let key = cacheKey(for: url)
        let safe = key.count > 200 ? String(key.prefix(200)) : key
        return cacheDirectory.appendingPathComponent("\(safe).cache", isDirectory: false)
    }

    static func save(_ data: Data, for url: URL) {
        let fileUrl = path(for: url)
        try? data.write(to: fileUrl)
    }

    static func load(for url: URL) -> Data? {
        let fileUrl = path(for: url)
        guard fileManager.fileExists(atPath: fileUrl.path) else { return nil }
        return try? Data(contentsOf: fileUrl)
    }

    static func hasCachedImage(for url: URL) -> Bool {
        fileManager.fileExists(atPath: path(for: url).path)
    }
}
