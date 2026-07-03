//
//  AppleCalendarImportManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import EventKit

/// Apple 日历导入管理器
/// 用于跟踪已导入的事件，避免重复导入，以及执行自动导入
/// 注意：只保存在本地，不保存到 Firebase，避免增加负担
/// 用户登出或删除 app 重新下载后，可以再次导入
final class AppleCalendarImportManager {
    static let shared = AppleCalendarImportManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let importedEventsKey = "importedAppleCalendarEvents"
    private let calendarManager = AppleCalendarManager.shared
    
    /// 检查事件是否已导入
    func isEventImported(appleEventId: String, for userId: String) -> Bool {
        let key = "\(importedEventsKey)_\(userId)"
        guard let data = userDefaults.data(forKey: key),
              let importedIds = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return false
        }
        return importedIds.contains(appleEventId)
    }
    
    /// 标记事件为已导入（只保存在本地）
    func markEventAsImported(appleEventId: String, appEventId: Int?, for userId: String) {
        let key = "\(importedEventsKey)_\(userId)"
        var importedIds: Set<String>
        
        // 从本地加载已导入的ID
        if let data = userDefaults.data(forKey: key),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            importedIds = ids
        } else {
            importedIds = Set<String>()
        }
        
        // 添加新的ID
        importedIds.insert(appleEventId)
        
        // 只保存到本地（不保存到 Firebase）
        if let encoded = try? JSONEncoder().encode(importedIds) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    /// 批量标记事件为已导入（只保存在本地）
    func markEventsAsImported(events: [(appleEventId: String, appEventId: Int?)], for userId: String) {
        let key = "\(importedEventsKey)_\(userId)"
        var importedIds: Set<String>
        
        // 从本地加载已导入的ID
        if let data = userDefaults.data(forKey: key),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            importedIds = ids
        } else {
            importedIds = Set<String>()
        }
        
        // 添加所有新的ID
        for event in events {
            importedIds.insert(event.appleEventId)
        }
        
        // 只保存到本地（不保存到 Firebase）
        if let encoded = try? JSONEncoder().encode(importedIds) {
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    /// 获取所有已导入的事件ID
    func getAllImportedEventIds(for userId: String) -> Set<String> {
        let key = "\(importedEventsKey)_\(userId)"
        guard let data = userDefaults.data(forKey: key),
              let importedIds = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            return Set<String>()
        }
        return importedIds
    }
    
    // MARK: - 自动导入功能
    
    /// 执行自动导入
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - lookAheadDays: 向前查找的天数（默认30天）
    /// - Returns: 导入成功的事件数量
    @MainActor
    func performAutoImport(for userId: String, lookAheadDays: Int = 30) async -> Int {
        // 检查是否启用自动导入
        guard UserPreferencesManager.shared.getAutoImportAppleCalendar(for: userId) else {
            print("📅 自动导入未启用，跳过")
            return 0
        }
        
        // 检查权限
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized else {
            print("⚠️ 日历权限未授权，无法自动导入")
            return 0
        }
        
        // 请求权限（如果需要）
        var hasPermission = false
        await withCheckedContinuation { continuation in
            calendarManager.requestAccessIfNeeded { granted in
                hasPermission = granted
                continuation.resume()
            }
        }
        
        guard hasPermission else {
            print("⚠️ 未获得日历权限，无法自动导入")
            return 0
        }
        
        // 定义日期范围：从现在到未来N天
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: lookAheadDays, to: startDate) ?? startDate
        
        // 获取 Apple 日历事件
        let appleEvents = await calendarManager.fetchEventsAsync(startDate: startDate, endDate: endDate)
        
        // 获取已导入的事件ID
        let importedIds = getAllImportedEventIds(for: userId)
        
        // 过滤出未导入的事件
        let newEvents = appleEvents.filter { event in
            guard let identifier = event.eventIdentifier else { return false }
            return !importedIds.contains(identifier)
        }
        
        guard !newEvents.isEmpty else {
            print("📅 没有新的 Apple 日历事件需要导入")
            return 0
        }
        
        print("📅 发现 \(newEvents.count) 个新的 Apple 日历事件，开始自动导入...")
        
        // 导入新事件
        var successCount = 0
        var importResults: [(appleEventId: String, appEventId: Int?)] = []
        
        for ekEvent in newEvents {
            guard let appleEventId = ekEvent.eventIdentifier else { continue }
            
            // 转换为应用事件格式
            let event = convertEKEventToEvent(ekEvent, userId: userId)
            
            // 只保存到本地缓存，不保存到 Firebase
            EventCacheManager.shared.addEventToCache(event, for: userId)
            
            // 记录导入结果
            importResults.append((appleEventId: appleEventId, appEventId: event.id))
            successCount += 1
            
            print("✅ 自动导入成功（仅本地）: \(ekEvent.title ?? "未知")")
        }
        
        // 批量标记为已导入（只保存在本地）
        if !importResults.isEmpty {
            markEventsAsImported(
                events: importResults,
                for: userId
            )
        }
        
        if successCount > 0 {
            print("✅ 自动导入完成，成功导入 \(successCount) 个事件")
            // 通知刷新事件列表
            NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
        }
        
        return successCount
    }
    
    /// 将 EKEvent 转换为 Event
    private func convertEKEventToEvent(_ ekEvent: EKEvent, userId: String) -> Event {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let startDate = ekEvent.startDate ?? Date()
        let endDate = ekEvent.endDate ?? startDate
        
        let dateString = dateFormatter.string(from: startDate)
        let startTimeString: String
        let endTimeString: String
        let isAllDay: Bool
        
        if ekEvent.isAllDay {
            isAllDay = true
            startTimeString = "00:00:00"
            endTimeString = "23:59:59"
        } else {
            isAllDay = false
            startTimeString = timeFormatter.string(from: startDate)
            endTimeString = timeFormatter.string(from: endDate)
        }
        
        // 处理跨日事件
        let endDateString: String?
        if !ekEvent.isAllDay && !Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            endDateString = dateFormatter.string(from: endDate)
        } else {
            endDateString = nil
        }
        
        // 构建备注信息
        var information = ""
        if let notes = ekEvent.notes, !notes.isEmpty {
            information = notes
        }
        if let location = ekEvent.location, !location.isEmpty {
            if !information.isEmpty {
                information += "\n\n"
            }
            information += "地点：\(location)"
        }
        
        let createTimeFormatter = DateFormatter()
        createTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // 使用 Apple 日曆識別符標記為外部匯入（非 default/event 即為外部來源）
        let calendarComp = ekEvent.calendar?.calendarIdentifier ?? "apple"
        
        return Event(
            title: ekEvent.title ?? "未命名事件",
            creatorOpenid: userId,
            color: "#FF6280",
            date: dateString,
            startTime: startTimeString,
            endTime: endTimeString,
            endDate: endDateString,
            destination: ekEvent.location ?? "",
            mapObj: "",
            openChecked: 0,
            personChecked: 0,
            createTime: createTimeFormatter.string(from: Date()),
            information: information.isEmpty ? nil : information,
            isAllDay: isAllDay,
            repeatType: "never",
            calendarComponent: calendarComp
        )
    }
}
