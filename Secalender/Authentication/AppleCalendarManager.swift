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
}
