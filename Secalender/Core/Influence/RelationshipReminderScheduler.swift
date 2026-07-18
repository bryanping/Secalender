//
//  RelationshipReminderScheduler.swift
//  Secalender
//
//  關係維護提醒：拉取 getReviewSummary.staleContacts，排程本地推播
//  不自動發送，需 App 啟動或每日背景刷新時呼叫 refresh()
//

import Foundation
import UserNotifications

enum RelationshipReminderScheduler {

    private static let categoryId = "relationship_reminder"
    private static let idPrefix = "rel_reminder_"

    /// 請求推播權限（App 首次進入回顧頁或設定開啟提醒時呼叫）
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// 刷新提醒：清掉舊的，依 staleContacts 重新排程
    /// - Parameters:
    ///   - staleDays: 久未聯絡門檻天數
    ///   - maxReminders: 一次最多排程幾位（避免洗版）
    ///   - hour: 每日提醒時間（24h）
    static func refresh(staleDays: Int = 60, maxReminders: Int = 3, hour: Int = 10) async {
        let center = UNUserNotificationCenter.current()

        // 需已授權
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else { return }

        guard let raw = await MetricService.fetchReviewSummary(staleDays: staleDays) else { return }
        let summary = ReviewSummary.parse(raw)

        // 清除本模組舊排程
        let pending = await center.pendingNotificationRequests()
        let oldIds = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIds)

        let targets = Array(summary.staleContacts.prefix(maxReminders))
        guard !targets.isEmpty else { return }

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0

        for (i, c) in targets.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "久未聯絡"
            content.body = "你和 \(c.displayName) 已 \(c.days) 天沒見了，要不要約個時間？"
            content.sound = .default
            content.categoryIdentifier = categoryId
            content.userInfo = ["contactId": c.id]

            // 錯開觸發日，一天一位
            var trigComps = comps
            let base = Calendar.current.date(
                byAdding: .day, value: i, to: Date()
            ) ?? Date()
            let day = Calendar.current.dateComponents([.year, .month, .day], from: base)
            trigComps.year = day.year
            trigComps.month = day.month
            trigComps.day = day.day

            let trigger = UNCalendarNotificationTrigger(dateMatching: trigComps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(idPrefix)\(c.id)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// 使用者關閉提醒時清除
    static func clearAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
