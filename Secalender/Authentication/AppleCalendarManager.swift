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
            hasPermission = (status == .authorized)
        }
    }

    /// 请求权限（如果尚未授权）
    func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                    completion(granted)
                }
            }
        case .authorized:
            self.hasPermission = true
            completion(true)
        default:
            self.hasPermission = false
            completion(false)
        }
    }

    /// 异步添加活动到 Apple 行事历
    func addEventToAppleCalendar(
        title: String,
        start: Date,
        end: Date,
        location: String?,
        notes: String?
    ) async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized else {
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
    }

    /// 读取某个时间段内的 Apple 行事历事件（用于比对/展示）
    func fetchEvents(startDate: Date, endDate: Date) {
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        DispatchQueue.main.async {
            self.fetchedEvents = events
        }
    }
    
    /// 获取用户的所有日历列表
    func getUserCalendars() -> [EKCalendar] {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized else {
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
