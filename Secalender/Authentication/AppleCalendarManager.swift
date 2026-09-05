//
//  AppleCalendarManager.swift
//  Secalender
//
//  Created by ChatGPT on 2025/6/24.
//

import EventKit
import Foundation

final class AppleCalendarManager: ObservableObject {
    static let shared = AppleCalendarManager()

    private let eventStore = EKEventStore()
    @Published var hasPermission: Bool = false
    @Published var fetchedEvents: [EKEvent] = []

    private init() {
        Task {
            let status = EKEventStore.authorizationStatus(for: .event)
            let hasAccess: Bool
            if #available(iOS 17.0, *) {
                hasAccess = (status == .fullAccess || status == .writeOnly)
            } else {
                hasAccess = (status == .authorized)
            }
            hasPermission = hasAccess
        }
    }

    /// 请求权限（如果尚未授权）
    func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                    DispatchQueue.main.async {
                        self?.hasPermission = granted
                        completion(granted)
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                    DispatchQueue.main.async {
                        self?.hasPermission = granted
                        completion(granted)
                    }
                }
            }
        case .authorized, .fullAccess, .writeOnly:
            self.hasPermission = true
            completion(true)
        default:
            self.hasPermission = false
            completion(false)
        }
    }


    /// 修改内容：P0-5 — iOS 17+ 授權後狀態為 .fullAccess（.authorized 已棄用），
    /// 原判斷只認 .authorized 導致 iOS 17 上讀寫全部失敗。統一在此判斷。
    private var hasCalendarAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess || status == .authorized
        } else {
            return status == .authorized
        }
    }

    // MARK: - 修改内容：Phase 2-E — App↔Apple 事件映射（雙向同步 v1）
    // App 事件 id → EKEvent identifier，供編輯/刪除回寫 Apple 日曆。
    private let syncMapKey = "apple_event_sync_map"
    private var syncMap: [String: String] {
        get { (UserDefaults.standard.dictionary(forKey: syncMapKey) as? [String: String]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: syncMapKey) }
    }
    func linkedAppleEventId(for eventId: Int) -> String? { syncMap[String(eventId)] }
    private func setLink(eventId: Int, appleId: String?) {
        var m = syncMap
        if let appleId = appleId { m[String(eventId)] = appleId } else { m.removeValue(forKey: String(eventId)) }
        syncMap = m
    }

    /// 异步添加活动到 Apple 行事历
    /// 修改内容：Phase 2-E — 傳入 eventId 時記錄映射，之後編輯/刪除可回寫
    func addEventToAppleCalendar(
        title: String,
        start: Date,
        end: Date,
        location: String?,
        notes: String?,
        eventId: Int? = nil
    ) async throws {
        guard hasCalendarAccess else {  // 修改内容：P0-5
            throw NSError(domain: "AppleCalendar", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "请前往设置开启日历权限"
            ])
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.location = location
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)

        if let eventId = eventId, let appleId = event.eventIdentifier {
            setLink(eventId: eventId, appleId: appleId)  // 修改内容：Phase 2-E
        }
    }

    /// 修改内容：Phase 2-E — App 端更新回寫 Apple（僅曾同步過的事件）
    func updateSyncedEvent(
        eventId: Int,
        title: String,
        start: Date,
        end: Date,
        location: String?,
        notes: String?
    ) {
        guard hasCalendarAccess,
              let appleId = linkedAppleEventId(for: eventId),
              let ek = eventStore.event(withIdentifier: appleId) else { return }
        ek.title = title
        ek.startDate = start
        ek.endDate = end
        ek.location = location
        ek.notes = notes
        do {
            try eventStore.save(ek, span: .thisEvent)
            print("✅ [AppleSync] 已回寫更新: \(title)")
        } catch {
            print("⚠️ [AppleSync] 回寫更新失敗: \(error.localizedDescription)")
        }
    }

    /// 修改内容：Phase 2-E — App 端刪除回寫 Apple（僅曾同步過的事件）
    func removeSyncedEvent(eventId: Int) {
        defer { setLink(eventId: eventId, appleId: nil) }
        guard hasCalendarAccess,
              let appleId = linkedAppleEventId(for: eventId),
              let ek = eventStore.event(withIdentifier: appleId) else { return }
        do {
            try eventStore.remove(ek, span: .thisEvent)
            print("✅ [AppleSync] 已回寫刪除")
        } catch {
            print("⚠️ [AppleSync] 回寫刪除失敗: \(error.localizedDescription)")
        }
    }

    /// 读取某个时间段内的 Apple 行事历事件（用于比对/展示）
    func fetchEvents(startDate: Date, endDate: Date) {
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        DispatchQueue.main.async {
            self.fetchedEvents = events
        }
    }
    
    /// 异步读取某个时间段内的 Apple 行事历事件（用于导入）
    func fetchEventsAsync(startDate: Date, endDate: Date) async -> [EKEvent] {
        guard hasCalendarAccess else {  // 修改内容：P0-5
            return []
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    // MARK: - 修改内容：Apple 匯入 Step2 — 匯入來源需含唯讀日曆（訂閱／節日／共享）
    /// 取得所有事件日曆（含唯讀），依帳號來源與名稱排序
    func getAllEventCalendars() -> [EKCalendar] {
        guard hasCalendarAccess else { return [] }
        return eventStore.calendars(for: .event).sorted {
            let s0 = $0.source?.title ?? ""
            let s1 = $1.source?.title ?? ""
            return s0 == s1 ? $0.title < $1.title : s0 < s1
        }
    }

    /// 讀取指定日曆在時間範圍內的事件
    func fetchEventsAsync(startDate: Date, endDate: Date, calendars: [EKCalendar]?) async -> [EKEvent] {
        guard hasCalendarAccess else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        return eventStore.events(matching: predicate)
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }

    /// 依識別符取得 Apple 事件（管理頁重新同步用）
    func event(withIdentifier identifier: String) -> EKEvent? {
        guard hasCalendarAccess else { return nil }
        return eventStore.event(withIdentifier: identifier)
    }

    /// 依識別符取得日曆
    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        guard hasCalendarAccess else { return nil }
        return eventStore.calendar(withIdentifier: identifier)
    }

    /// 获取用户的所有日历列表
    func getUserCalendars() -> [EKCalendar] {
        guard hasCalendarAccess else {  // 修改内容：P0-5
            return []
        }
        
        // 获取所有可用的日历
        let calendars = eventStore.calendars(for: .event)
        // 过滤掉只读日历，只返回可写入的日历
        return calendars.filter { $0.allowsContentModifications }
    }
    
    /// 将EKCalendar转换为UserCalendar
    func convertToUserCalendars(_ ekCalendars: [EKCalendar]) -> [UserCalendar] {
        return ekCalendars.map { calendar in
            guard let color = calendar.cgColor else {
                return UserCalendar(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    colorHex: "FF0000" // 默认红色
                )
            }
            let colorHex = colorToHex(color)
            return UserCalendar(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                colorHex: colorHex
            )
        }
    }
    
    /// 将CGColor转换为十六进制字符串
    private func colorToHex(_ color: CGColor) -> String {
        guard let components = color.components, components.count >= 3 else {
            return "FF0000" // 默认红色
        }
        
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
