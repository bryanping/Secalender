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
}

