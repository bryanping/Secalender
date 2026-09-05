//
//  Utilities.swift
//  Secalender
//
//  Created by linping on 2024/6/20.
//

import Foundation
import UIKit
import UserNotifications

final class Utilities {
    
    static let shared = Utilities()
    private init () {}
    
    
    @MainActor
    func topViewController(controller: UIViewController? = nil) -> UIViewController? {
        // 使用场景 API 替代已弃用的 keyWindow（iOS 13+）
        let rootViewController: UIViewController?
        if let providedController = controller {
            rootViewController = providedController
        } else {
            // 尝试从场景获取 key window
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                rootViewController = window.rootViewController
            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first {
                // 如果没有 key window，使用第一个窗口
                rootViewController = window.rootViewController
            } else {
                rootViewController = nil
            }
        }
        
        guard let controller = rootViewController else {
            return nil
        }
         
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}

// MARK: - 修改内容：Phase 1-A — 持久化日期字串專用 formatter
// 裝置若為佛曆/和曆（zh_TW@calendar=buddhist 等）或非公曆設定，
// 預設 DateFormatter 會把 "yyyy" 寫成 2569 等錯誤年份存進 Firebase。
// 所有「寫入/解析儲存字串」一律使用此工廠；純顯示用 formatter 不受影響。
extension DateFormatter {
    static func stable(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }
}

// MARK: - 修改内容：Phase 2-C — 事件本地提醒（v1：開始前 30 分鐘）
// 全專案原本沒有任何事件提醒。儲存事件時排定、刪除時取消。
final class EventReminderScheduler {
    static let shared = EventReminderScheduler()
    private init() {}

    static let leadMinutes = 30

    private func identifier(for eventId: Int) -> String { "event_reminder_\(eventId)" }

    private func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    /// 排定提醒（開始前 30 分鐘；已過去、無 id 或無開始時間則略過）
    func schedule(for event: Event) {
        guard let id = event.id, let start = event.startDateTime else { return }
        let fireDate = start.addingTimeInterval(-TimeInterval(Self.leadMinutes * 60))
        guard fireDate > Date() else { return }
        requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = event.title.isEmpty ? "行程提醒" : event.title
        var body = String(event.startTime.prefix(5)) + " 開始"
        if !event.destination.isEmpty { body += " · " + event.destination }
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier(for: id), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("⚠️ [Reminder] 排定失敗: \(error.localizedDescription)") }
        }
    }

    func cancel(eventId: Int) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: eventId)])
    }
}
