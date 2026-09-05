//
//  UserPreferencesManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import Firebase
import FirebaseFirestore
import SwiftUI
import UIKit

/// 用户偏好设置管理器
final class UserPreferencesManager {
    static let shared = UserPreferencesManager()
    private init() {}
    
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    private let syncToAppleCalendarKey = "syncToAppleCalendarDefault"
    private let userCalendarsKey = "userCalendars"
    private let autoImportAppleCalendarKey = "autoImportAppleCalendar"
    
    // MARK: - 同步到Apple日历默认设置
    
    /// 获取同步到Apple日历的默认设置
    func getSyncToAppleCalendarDefault(for userId: String) -> Bool {
        // 先从本地缓存读取
        if let cached = userDefaults.object(forKey: "\(syncToAppleCalendarKey)_\(userId)") as? Bool {
            return cached
        }
        return false
    }
    
    /// 设置同步到Apple日历的默认值
    func setSyncToAppleCalendarDefault(_ value: Bool, for userId: String) async throws {
        // 保存到本地缓存
        userDefaults.set(value, forKey: "\(syncToAppleCalendarKey)_\(userId)")
        
        // 保存到Firebase
        try await db.collection("user_preferences")
            .document(userId)
            .setData([
                "syncToAppleCalendarDefault": value,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }
    
    /// 从Firebase加载同步到Apple日历的默认设置
    func loadSyncToAppleCalendarDefault(for userId: String) async throws {
        let doc = try await db.collection("user_preferences")
            .document(userId)
            .getDocument()
        
        if let data = doc.data(),
           let value = data["syncToAppleCalendarDefault"] as? Bool {
            // 更新本地缓存
            userDefaults.set(value, forKey: "\(syncToAppleCalendarKey)_\(userId)")
        }
    }
    
    // MARK: - 用户日历列表
    
    /// 保存用户日历列表到本地和Firebase
    func saveUserCalendars(_ calendars: [UserCalendar], for userId: String) async throws {
        // 转换为可存储的格式
        let calendarsData = calendars.map { calendar in
            [
                "id": calendar.id,
                "title": calendar.title,
                "color": calendar.colorHex
            ]
        }
        
        // 保存到本地缓存
        if let encoded = try? JSONEncoder().encode(calendars) {
            userDefaults.set(encoded, forKey: "\(userCalendarsKey)_\(userId)")
        }
        
        // 保存到Firebase
        try await db.collection("user_preferences")
            .document(userId)
            .setData([
                "calendars": calendarsData,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }
    
    /// 从本地缓存加载用户日历列表
    func loadUserCalendarsFromCache(for userId: String) -> [UserCalendar] {
        guard let data = userDefaults.data(forKey: "\(userCalendarsKey)_\(userId)"),
              let calendars = try? JSONDecoder().decode([UserCalendar].self, from: data) else {
            return []
        }
        return calendars
    }
    
    /// 从Firebase加载用户日历列表
    func loadUserCalendarsFromFirebase(for userId: String) async throws -> [UserCalendar] {
        let doc = try await db.collection("user_preferences")
            .document(userId)
            .getDocument()
        
        guard let data = doc.data(),
              let calendarsArray = data["calendars"] as? [[String: Any]] else {
            return []
        }
        
        let calendars = calendarsArray.compactMap { dict -> UserCalendar? in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let colorHex = dict["color"] as? String else {
                return nil
            }
            return UserCalendar(id: id, title: title, colorHex: colorHex)
        }
        
        // 更新本地缓存
        if let encoded = try? JSONEncoder().encode(calendars) {
            userDefaults.set(encoded, forKey: "\(userCalendarsKey)_\(userId)")
        }
        
        return calendars
    }
    
    // MARK: - 自动导入 Apple 日历设置
    
    /// 获取自动导入 Apple 日历的设置
    func getAutoImportAppleCalendar(for userId: String) -> Bool {
        // 先从本地缓存读取
        if let cached = userDefaults.object(forKey: "\(autoImportAppleCalendarKey)_\(userId)") as? Bool {
            return cached
        }
        return false
    }
    
    /// 设置自动导入 Apple 日历
    func setAutoImportAppleCalendar(_ value: Bool, for userId: String) async throws {
        // 保存到本地缓存
        userDefaults.set(value, forKey: "\(autoImportAppleCalendarKey)_\(userId)")
        
        // 保存到Firebase
        try await db.collection("user_preferences")
            .document(userId)
            .setData([
                "autoImportAppleCalendar": value,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }
    
    /// 从Firebase加载自动导入设置
    func loadAutoImportAppleCalendar(for userId: String) async throws {
        let doc = try await db.collection("user_preferences")
            .document(userId)
            .getDocument()
        
        if let data = doc.data(),
           let value = data["autoImportAppleCalendar"] as? Bool {
            // 更新本地缓存
            userDefaults.set(value, forKey: "\(autoImportAppleCalendarKey)_\(userId)")
        }
    }

    // MARK: - 修改内容：Apple 同步 Step5 — 以「來源日曆」為單位的同步設定

    private func syncedCalendarIdsKey(_ userId: String) -> String {
        "syncedAppleCalendarIds_\(userId)"
    }
    private func syncPastMonthsKey(_ userId: String) -> String {
        "appleSyncPastMonths_\(userId)"
    }
    private func syncFutureMonthsKey(_ userId: String) -> String {
        "appleSyncFutureMonths_\(userId)"
    }

    /// 已訂閱同步的來源日曆識別符（僅這些日曆會被同步）
    func getSyncedCalendarIds(for userId: String) -> Set<String> {
        Set(userDefaults.stringArray(forKey: syncedCalendarIdsKey(userId)) ?? [])
    }

    func setSyncedCalendarIds(_ ids: Set<String>, for userId: String) {
        userDefaults.set(Array(ids), forKey: syncedCalendarIdsKey(userId))
    }

    /// 同步範圍：往前幾個月（預設 12，涵蓋舊行程）
    func getSyncPastMonths(for userId: String) -> Int {
        let value = userDefaults.integer(forKey: syncPastMonthsKey(userId))
        return value == 0 ? 12 : value
    }

    func setSyncPastMonths(_ months: Int, for userId: String) {
        userDefaults.set(months, forKey: syncPastMonthsKey(userId))
    }

    /// 同步範圍：往後幾個月（預設 12）
    func getSyncFutureMonths(for userId: String) -> Int {
        let value = userDefaults.integer(forKey: syncFutureMonthsKey(userId))
        return value == 0 ? 12 : value
    }

    func setSyncFutureMonths(_ months: Int, for userId: String) {
        userDefaults.set(months, forKey: syncFutureMonthsKey(userId))
    }
}

