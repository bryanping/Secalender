//
//  AppleCalendarImportManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import EventKit
import CoreGraphics

// MARK: - 修改内容：Apple 匯入 Step1 — 匯入紀錄結構化（原為 Set<String>，無法管理）
/// 單筆匯入紀錄：以 occurrenceKey（appleEventId|yyyy-MM-dd）為唯一鍵
struct AppleImportRecord: Codable, Identifiable, Hashable {
    let occurrenceKey: String
    let appleEventId: String
    let appEventId: Int
    var title: String
    var date: String
    var startTime: String
    var isAllDay: Bool
    var calendarId: String
    var calendarTitle: String
    var importedAt: Date

    var id: String { occurrenceKey }
}

/// Apple 日历导入管理器
/// 负责：匯入去重（occurrence 級）、匯入紀錄管理（查詢/移除）、自动导入
/// 注意：只保存在本地，不保存到 Firebase
final class AppleCalendarImportManager {
    static let shared = AppleCalendarImportManager()
    private init() {}

    private let userDefaults = UserDefaults.standard
    private let legacyImportedEventsKey = "importedAppleCalendarEvents"   // 舊版 Set<String>
    private let recordsKey = "appleImportRecords"                          // 新版 [AppleImportRecord]
    private let calendarManager = AppleCalendarManager.shared
    // 修改内容：Step14 — 全量同步範圍（EventKit 需要明確區間，取足夠寬的範圍代表「全部」）
    private static let syncYearsBack = 1
    private static let syncYearsForward = 3

    // MARK: - 儲存

    private func recordsStorageKey(_ userId: String) -> String { "\(recordsKey)_\(userId)" }
    private func legacyStorageKey(_ userId: String) -> String { "\(legacyImportedEventsKey)_\(userId)" }

    /// 讀取全部匯入紀錄（含舊版資料遷移）
    func records(for userId: String) -> [AppleImportRecord] {
        let key = recordsStorageKey(userId)
        if let data = userDefaults.data(forKey: key),
           let list = try? JSONDecoder().decode([AppleImportRecord].self, from: data) {
            return list
        }
        // 修改内容：Apple 匯入 Step1 — 舊版資料清理（一次性）
        // 舊版只存 Set<appleEventId>，匯入的行程 id 為 nil，會在每次刷新被丟棄並產生重覆副本，
        // 無法對應到新版 occurrence 紀錄；因此清空舊標記與殘留副本，讓使用者以新機制重新匯入一次。
        // 修改内容：Apple 同步 Step6 — 舊標記直接作廢；快取中的舊行程改由 cleanupDuplicates 正規化並補建紀錄，
        // 使其可在管理頁查看與刪除（原本直接清除，導致使用者看得到卻管不到）。
        userDefaults.removeObject(forKey: legacyStorageKey(userId))
        saveRecords([], for: userId)
        return []
    }

    private func saveRecords(_ list: [AppleImportRecord], for userId: String) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        userDefaults.set(data, forKey: recordsStorageKey(userId))
    }

    // MARK: - 查詢

    /// 該次發生是否已匯入
    func isOccurrenceImported(_ occurrenceKey: String, for userId: String) -> Bool {
        records(for: userId).contains { $0.occurrenceKey == occurrenceKey }
    }

    /// 該 Apple 事件是否有任一次已匯入（列表顯示「已導入」標記用）
    func isEventImported(appleEventId: String, for userId: String) -> Bool {
        records(for: userId).contains { $0.appleEventId == appleEventId }
    }

    /// 所有已匯入的 Apple 事件識別符
    func getAllImportedEventIds(for userId: String) -> Set<String> {
        Set(records(for: userId).map { $0.appleEventId })
    }

    /// 所有已匯入的 occurrenceKey
    func importedOccurrenceKeys(for userId: String) -> Set<String> {
        Set(records(for: userId).map { $0.occurrenceKey })
    }

    /// 所有已匯入的本地事件 id
    func importedAppEventIds(for userId: String) -> Set<Int> {
        Set(records(for: userId).map { $0.appEventId })
    }

    /// 依來源日曆分組（管理頁用）
    func recordsGroupedByCalendar(for userId: String) -> [(calendarId: String, calendarTitle: String, records: [AppleImportRecord])] {
        let grouped = Dictionary(grouping: records(for: userId)) { $0.calendarId }
        return grouped.map { key, value in
            let title = value.first?.calendarTitle ?? ""
            return (calendarId: key,
                    calendarTitle: title.isEmpty ? "未知日曆" : title,
                    records: value.sorted { ($0.date, $0.startTime) < ($1.date, $1.startTime) })
        }
        .sorted { $0.calendarTitle < $1.calendarTitle }
    }

    // MARK: - 標記

    /// 批量寫入匯入紀錄（以 occurrenceKey 去重覆蓋）
    func markRecordsAsImported(_ newRecords: [AppleImportRecord], for userId: String) {
        var map = Dictionary(uniqueKeysWithValues: records(for: userId).map { ($0.occurrenceKey, $0) })
        for record in newRecords {
            map[record.occurrenceKey] = record
        }
        saveRecords(Array(map.values), for: userId)
    }

    // MARK: - 移除（管理功能）

    /// 移除指定匯入紀錄，並同步刪除本地快取中的行程
    func removeImported(occurrenceKeys: Set<String>, for userId: String) {
        let all = records(for: userId)
        let removed = all.filter { occurrenceKeys.contains($0.occurrenceKey) }
        let kept = all.filter { !occurrenceKeys.contains($0.occurrenceKey) }
        saveRecords(kept, for: userId)

        for record in removed {
            EventCacheManager.shared.removeEventFromCache(eventId: record.appEventId, for: userId)
        }
        NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
    }

    /// 依本地事件 id 移除匯入紀錄（本地行程已被刪除時呼叫，不再重覆刪快取）
    func removeImportRecord(appEventId: Int, for userId: String) {
        let all = records(for: userId)
        guard all.contains(where: { $0.appEventId == appEventId }) else { return }
        saveRecords(all.filter { $0.appEventId != appEventId }, for: userId)
    }

    /// 移除某來源日曆的全部匯入內容
    func removeImportedCalendar(calendarId: String, for userId: String) {
        let keys = Set(records(for: userId).filter { $0.calendarId == calendarId }.map { $0.occurrenceKey })
        removeImported(occurrenceKeys: keys, for: userId)
    }

    /// 清除全部匯入內容
    func removeAllImported(for userId: String) {
        let keys = Set(records(for: userId).map { $0.occurrenceKey })
        removeImported(occurrenceKeys: keys, for: userId)
        userDefaults.removeObject(forKey: legacyStorageKey(userId))
    }

    // MARK: - 匯入核心

    /// 將 EKEvent 陣列匯入（統一入口，導入頁與自動導入共用）
    /// - Returns: (成功筆數, 跳過筆數)
    @discardableResult
    @MainActor
    func importEvents(_ ekEvents: [EKEvent], for userId: String) -> (imported: Int, skipped: Int) {
        let existing = records(for: userId)
        let existingKeys = Set(existing.map { $0.occurrenceKey })
        // 修改内容：Apple 匯入 Step4 — 內容簽章去重：同一節日同時存在於多個訂閱日曆時只保留一份
        var existingSignatures = Set(existing.map { contentSignature(title: $0.title, date: $0.date, startTime: $0.startTime, isAllDay: $0.isAllDay) })
        var seenKeys = Set<String>()          // 修改内容：Apple 匯入 Step1 — 同批次內去重（重複事件多次發生）
        var newRecords: [AppleImportRecord] = []
        var imported = 0
        var skipped = 0

        for ekEvent in ekEvents {
            guard let appleEventId = ekEvent.eventIdentifier else { skipped += 1; continue }
            let event = makeEvent(from: ekEvent, userId: userId)
            guard let occurrenceKey = event.appleOccurrenceKey, let appEventId = event.id else {
                skipped += 1
                continue
            }
            if existingKeys.contains(occurrenceKey) || seenKeys.contains(occurrenceKey) {
                skipped += 1
                continue
            }
            let signature = contentSignature(
                title: event.title,
                date: event.date,
                startTime: event.startTime,
                isAllDay: event.isAllDay ?? false
            )
            if existingSignatures.contains(signature) {
                skipped += 1
                continue
            }
            existingSignatures.insert(signature)
            seenKeys.insert(occurrenceKey)

            EventCacheManager.shared.addEventToCache(event, for: userId)

            newRecords.append(
                AppleImportRecord(
                    occurrenceKey: occurrenceKey,
                    appleEventId: appleEventId,
                    appEventId: appEventId,
                    title: event.title,
                    date: event.date,
                    startTime: event.startTime,
                    isAllDay: event.isAllDay ?? false,
                    calendarId: ekEvent.calendar?.calendarIdentifier ?? "",
                    calendarTitle: ekEvent.calendar?.title ?? "",
                    importedAt: Date()
                )
            )
            imported += 1
        }

        if !newRecords.isEmpty {
            markRecordsAsImported(newRecords, for: userId)
            NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
        }
        return (imported, skipped)
    }

    // MARK: - 修改内容：Apple 匯入 Step4 — 重複內容清理

    /// 內容簽章：同標題／同日／同起始時間視為同一行程（跨來源日曆去重）
    private func contentSignature(title: String, date: String, startTime: String, isAllDay: Bool) -> String {
        "\(title)|\(date)|\(isAllDay ? "allday" : startTime)"
    }

    /// 是否為本 App 管理的匯入行程
    /// 僅涵蓋：新版匯入（含 appleEventId）與舊版本地匯入（無 id 或 id 落在 Apple 匯入區段），
    /// 避免誤動使用者自建、已存 Firestore 且指定了 Apple 日曆的行程。
    private func isManagedImport(_ event: Event) -> Bool {
        if event.isAppleImported { return true }
        guard event.isFromExternalImport else { return false }
        guard let id = event.id else { return true }
        return id <= -3_000_000 && id > -4_000_000
    }

    /// 全天正規化（仿 Apple 日曆）：
    /// 「00:00 → 隔日 00:00」屬於全天事件的排他邊界表示法，
    /// 應轉為 isAllDay ＋ 結束日內縮，否則詳情頁會顯示「上午12:00 → 隔日上午12:00」的 24 小時區間。
    private func normalizedAllDay(_ event: Event) -> Event {
        var normalized = event
        let startsAtMidnight = event.startTime == "00:00:00"
        let endsAtMidnight = event.endTime == "00:00:00" || event.endTime == "00:00"

        guard startsAtMidnight, endsAtMidnight || (event.isAllDay ?? false) else { return normalized }

        normalized.isAllDay = true
        normalized.startTime = "00:00:00"
        normalized.endTime = "23:59:59"

        if let endDateString = event.endDate,
           let start = event.dateObj,
           let end = DateFormatter.stable("yyyy-MM-dd").date(from: endDateString) {
            // 結束日為排他邊界（隔日 00:00）→ 內縮一天；同日則移除 endDate
            let inclusiveEnd = endsAtMidnight ? end.addingTimeInterval(-1) : end
            normalized.endDate = Calendar.current.isDate(start, inSameDayAs: inclusiveEnd)
                ? nil
                : DateFormatter.stable("yyyy-MM-dd").string(from: inclusiveEnd)
        }
        return normalized
    }

    /// 為先前版本匯入、沒有匯入紀錄的外部行程補建紀錄，使其可在管理頁查看與刪除
    private func backfillRecord(for event: Event) -> (event: Event, record: AppleImportRecord)? {
        guard event.isFromExternalImport, !event.isAppleImported else { return nil }
        let calendarId = event.calendarComponent ?? "legacy"
        let legacyAppleId = "legacy:\(calendarId)"
        let occurrenceKey = "\(legacyAppleId)|\(event.date)|\(event.title)"
        let appEventId = event.id ?? Event.appleStableId(occurrenceKey: occurrenceKey)
        let calendarTitle = AppleCalendarManager.shared.calendar(withIdentifier: calendarId)?.title ?? "先前匯入"

        var migrated = event
        migrated.id = appEventId
        migrated.appleEventId = legacyAppleId
        migrated.appleOccurrenceKey = occurrenceKey
        migrated.appleCalendarId = calendarId
        migrated.appleCalendarTitle = calendarTitle

        let record = AppleImportRecord(
            occurrenceKey: occurrenceKey,
            appleEventId: legacyAppleId,
            appEventId: appEventId,
            title: event.title,
            date: event.date,
            startTime: event.startTime,
            isAllDay: event.isAllDay ?? false,
            calendarId: calendarId,
            calendarTitle: calendarTitle,
            importedAt: Date(timeIntervalSince1970: 0)   // 舊資料排最前，去重時優先保留
        )
        return (migrated, record)
    }

    /// 清理／遷移已匯入內容（每次開啟行事曆、匯入頁、管理頁時執行）
    /// 1) 全天時間錯位正規化 2) 舊資料補建管理紀錄 3) 同內容去重 4) 已取消訂閱的孤兒移除
    /// - Returns: 清除的重複筆數
    @discardableResult
    @MainActor
    func cleanupDuplicates(for userId: String, force: Bool = false) -> Int {
        // 修改内容：Step18 — 節流：原本每次進入行事曆都全量掃描＋改寫快取，是卡頓來源
        let cleanupKey = "appleImportLastCleanup_\(userId)"
        if !force,
           let last = userDefaults.object(forKey: cleanupKey) as? Date,
           Date().timeIntervalSince(last) < 24 * 60 * 60 {
            return 0
        }
        userDefaults.set(Date(), forKey: cleanupKey)

        let cached = EventCacheManager.shared.loadEvents(for: userId)
        var recordMap = Dictionary(uniqueKeysWithValues: records(for: userId).map { ($0.occurrenceKey, $0) })

        // 有匯入紀錄者優先保留，其次為舊資料
        let ordered = cached.sorted { lhs, rhs in
            let l = lhs.isAppleImported ? 0 : 1
            let r = rhs.isAppleImported ? 0 : 1
            return l < r
        }

        var seenSignatures = Set<String>()
        var cleaned: [Event] = []
        var keptOccurrenceKeys = Set<String>()
        var removedCount = 0
        var changed = false

        for event in ordered {
            guard isManagedImport(event) else { cleaned.append(event); continue }

            // 1) 全天正規化
            var normalized = normalizedAllDay(event)
            if normalized.startTime != event.startTime
                || normalized.endTime != event.endTime
                || normalized.endDate != event.endDate
                || (normalized.isAllDay ?? false) != (event.isAllDay ?? false) {
                changed = true
            }

            // 2) 舊資料補建紀錄
            if !normalized.isAppleImported, let backfilled = backfillRecord(for: normalized) {
                normalized = backfilled.event
                if recordMap[backfilled.record.occurrenceKey] == nil {
                    recordMap[backfilled.record.occurrenceKey] = backfilled.record
                }
                changed = true
            }

            // 3) 同內容去重
            let signature = contentSignature(
                title: normalized.title,
                date: normalized.date,
                startTime: normalized.startTime,
                isAllDay: normalized.isAllDay ?? false
            )
            if seenSignatures.contains(signature) {
                removedCount += 1
                changed = true
                continue
            }
            seenSignatures.insert(signature)
            if let key = normalized.appleOccurrenceKey { keptOccurrenceKeys.insert(key) }
            cleaned.append(normalized)
        }

        // 4) 移除沒有對應行程的孤兒紀錄
        let prunedRecords = recordMap.values.filter { keptOccurrenceKeys.contains($0.occurrenceKey) }
        if prunedRecords.count != recordMap.count { changed = true }

        if changed {
            EventCacheManager.shared.saveEvents(cleaned, for: userId)
            saveRecords(Array(prunedRecords), for: userId)
            print("🧹 匯入資料整理完成：移除重複 \(removedCount) 筆，現有 \(prunedRecords.count) 筆紀錄")
            NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
        }
        return removedCount
    }

    // MARK: - 修改内容：Apple 匯入 Step3 — 重新同步（管理頁）

    /// 以 Apple 日曆為準更新已匯入內容：
    /// 來源已刪除者移除；內容或時間變更者更新（非重複事件支援日期異動重新編鍵）
    /// - Returns: (更新筆數, 移除筆數)
    @discardableResult
    @MainActor
    func resyncImported(for userId: String) -> (updated: Int, removed: Int) {
        var current = records(for: userId)
        var updated = 0
        var removed = 0
        var removedIds: [Int] = []
        var index = 0
        // 修改内容：Apple 匯入 Step4 — 快取只讀取一次，避免迴圈內重複解碼
        let cachedById: [Int: Event] = EventCacheManager.shared.loadEvents(for: userId)
            .reduce(into: [:]) { dict, event in
                if let id = event.id { dict[id] = event }
            }

        while index < current.count {
            let record = current[index]
            // 修改内容：Apple 同步 Step6 — 舊版補建紀錄無法對應 Apple 事件，略過不動（由使用者自行刪除）
            if record.appleEventId.hasPrefix("legacy:") {
                index += 1
                continue
            }
            guard let ekEvent = AppleCalendarManager.shared.event(withIdentifier: record.appleEventId) else {
                removedIds.append(record.appEventId)
                current.remove(at: index)
                removed += 1
                continue
            }

            let refreshed = makeEvent(from: ekEvent, userId: userId)
            let isRecurring = ekEvent.hasRecurrenceRules

            if !isRecurring, let newKey = refreshed.appleOccurrenceKey, newKey != record.occurrenceKey,
               let newId = refreshed.id {
                // 日期已異動：搬移為新的 occurrence
                EventCacheManager.shared.removeEventFromCache(eventId: record.appEventId, for: userId)
                EventCacheManager.shared.addEventToCache(refreshed, for: userId)
                current[index] = AppleImportRecord(
                    occurrenceKey: newKey,
                    appleEventId: record.appleEventId,
                    appEventId: newId,
                    title: refreshed.title,
                    date: refreshed.date,
                    startTime: refreshed.startTime,
                    isAllDay: refreshed.isAllDay ?? false,
                    calendarId: refreshed.appleCalendarId ?? record.calendarId,
                    calendarTitle: refreshed.appleCalendarTitle ?? record.calendarTitle,
                    importedAt: record.importedAt
                )
                updated += 1
            } else {
                // 內容更新：沿用原 id 覆寫快取，維持日曆上的位置
                // 修改内容：Apple 匯入 Step4 — 一律回寫，可修正舊資料的全天／跨日時間錯位
                var merged = refreshed
                merged.id = record.appEventId
                merged.date = record.date
                merged.appleOccurrenceKey = record.occurrenceKey

                let cached = cachedById[record.appEventId]
                let changed = cached == nil
                    || cached?.title != merged.title
                    || cached?.startTime != merged.startTime
                    || cached?.endTime != merged.endTime
                    || cached?.endDate != merged.endDate
                    || (cached?.isAllDay ?? false) != (merged.isAllDay ?? false)

                EventCacheManager.shared.addEventToCache(merged, for: userId)
                if changed {
                    current[index].title = refreshed.title
                    current[index].startTime = refreshed.startTime
                    current[index].isAllDay = refreshed.isAllDay ?? false
                    current[index].calendarTitle = refreshed.appleCalendarTitle ?? record.calendarTitle
                    updated += 1
                }
            }
            index += 1
        }

        saveRecords(current, for: userId)
        for id in removedIds {
            EventCacheManager.shared.removeEventFromCache(eventId: id, for: userId)
        }
        if updated > 0 || removed > 0 {
            NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
        }
        return (updated, removed)
    }

    // MARK: - 修改内容：Apple 同步 Step7 — 重複行程偵測（涵蓋更早版本、已寫入雲端的匯入殘留）

    /// 同一天、同標題的重複行程群組
    struct DuplicateGroup: Identifiable {
        let title: String
        let date: String
        /// 建議保留者排在最前（有同步來源者優先）
        let events: [Event]
        var id: String { "\(title)|\(date)" }
        var removable: [Event] { Array(events.dropFirst()) }
    }

    /// 掃描本地資料中同日同標題的重複行程
    /// 舊版本匯入的殘留可能沒有任何來源標記、甚至已同步到雲端，
    /// 只靠匯入紀錄無法清除，因此改以「內容重複」為判準交由使用者確認刪除。
    func duplicateEventGroups(for userId: String) -> [DuplicateGroup] {
        let events = EventCacheManager.shared.loadEvents(for: userId).filter { $0.deleted != 1 }
        let grouped = Dictionary(grouping: events) { "\($0.title)|\($0.date)" }

        return grouped.compactMap { _, list -> DuplicateGroup? in
            guard list.count > 1, let first = list.first else { return nil }
            let sorted = list.sorted { lhs, rhs in
                // 有 Apple 同步來源者優先保留，其次保留有 id 者
                let l = (lhs.isAppleImported ? 0 : 1, lhs.id == nil ? 1 : 0)
                let r = (rhs.isAppleImported ? 0 : 1, rhs.id == nil ? 1 : 0)
                return l < r
            }
            return DuplicateGroup(title: first.title, date: first.date, events: sorted)
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - 修改内容：Apple 同步 Step5 — 以來源日曆為單位的整體同步

    /// 同步指定來源日曆（含過去與未來範圍的既有行程）
    /// - Returns: 新匯入筆數
    @discardableResult
    @MainActor
    func syncCalendars(ids: Set<String>, for userId: String) async -> Int {
        guard !ids.isEmpty, await ensurePermission() else { return 0 }

        // 修改内容：Step14 — 不再限制時間區段，一次同步整個日曆
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .year, value: -Self.syncYearsBack, to: now) ?? now
        let end = calendar.date(byAdding: .year, value: Self.syncYearsForward, to: now) ?? now

        let targets = ids.compactMap { AppleCalendarManager.shared.calendar(withIdentifier: $0) }
        guard !targets.isEmpty else { return 0 }

        let events = await calendarManager.fetchEventsAsync(startDate: start, endDate: end, calendars: targets)
        let result = importEvents(events, for: userId)
        print("🔄 來源同步完成：新增 \(result.imported)，略過 \(result.skipped)")
        return result.imported
    }

    /// 同步全部已訂閱來源
    @discardableResult
    @MainActor
    func syncAllSubscribedCalendars(for userId: String) async -> Int {
        let ids = UserPreferencesManager.shared.getSyncedCalendarIds(for: userId)
        return await syncCalendars(ids: ids, for: userId)
    }

    /// 停止同步某來源，並可選擇一併移除已匯入行程
    @MainActor
    func unsubscribeCalendar(_ calendarId: String, removeImportedEvents: Bool, for userId: String) {
        var ids = UserPreferencesManager.shared.getSyncedCalendarIds(for: userId)
        ids.remove(calendarId)
        UserPreferencesManager.shared.setSyncedCalendarIds(ids, for: userId)
        if removeImportedEvents {
            removeImportedCalendar(calendarId: calendarId, for: userId)
        }
    }

    private func ensurePermission() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        let authorized: Bool
        if #available(iOS 17.0, *) {
            authorized = (status == .fullAccess || status == .authorized)
        } else {
            authorized = (status == .authorized)
        }
        if authorized { return true }

        return await withCheckedContinuation { continuation in
            calendarManager.requestAccessIfNeeded { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - 自动同步（App 啟動）

    /// 执行自动同步：同步全部已訂閱來源的新舊行程
    /// - Returns: 导入成功的事件数量
    @MainActor
    func performAutoImport(for userId: String, lookAheadDays: Int = 30) async -> Int {
        guard UserPreferencesManager.shared.getAutoImportAppleCalendar(for: userId) else {
            print("📅 自動同步未启用，跳过")
            return 0
        }

        guard await ensurePermission() else {
            print("⚠️ 未获得日历权限，无法自动同步")
            return 0
        }

        // 修改内容：Apple 同步 Step5 — 同步全部已訂閱來源（含過去行程），不再逐筆處理
        let imported = await syncAllSubscribedCalendars(for: userId)
        if imported > 0 {
            print("✅ 自動同步完成，新增 \(imported) 个行程")
        }
        return imported
    }

    // MARK: - 轉換

    /// 修改内容：Step19 — CGColor → #RRGGBB
    static func hexString(from color: CGColor) -> String? {
        // 轉為 sRGB 再取值，避免灰階／P3 色域取到錯誤分量
        let srgb = CGColorSpace(name: CGColorSpace.sRGB).flatMap {
            color.converted(to: $0, intent: .defaultIntent, options: nil)
        } ?? color
        guard let components = srgb.components, components.count >= 3 else { return nil }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }

    /// 修改内容：Step14 — Apple 重複規則 → App repeatType
    static func repeatType(of ekEvent: EKEvent) -> String {
        guard let rule = ekEvent.recurrenceRules?.first else { return "never" }
        // 僅支援間隔為 1 的基本週期；其餘（每 2 週等）仍存為單筆，避免展開錯誤
        guard rule.interval <= 1 else { return "never" }
        switch rule.frequency {
        case .daily: return "daily"
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .yearly: return "yearly"
        @unknown default: return "never"
        }
    }

    /// 将 EKEvent 转换为 Event（帶穩定 id 與來源標記）
    func makeEvent(from ekEvent: EKEvent, userId: String) -> Event {
        let dateFormatter = DateFormatter.stable("yyyy-MM-dd")
        let timeFormatter = DateFormatter.stable("HH:mm:ss")

        let calendar = Calendar.current
        let startDate = ekEvent.startDate ?? Date()
        let rawEndDate = ekEvent.endDate ?? startDate

        // 修改内容：Apple 匯入 Step4 — 全天事件時間錯位修正
        // 節日／訂閱日曆常以「00:00 → 隔日 00:00」表示單日全天事件，
        // 原邏輯直接取 endDate 的日期，導致單日行程被展開成「第1天／第2天」。
        let startsAtMidnight = calendar.dateComponents([.hour, .minute, .second], from: startDate)
            == DateComponents(hour: 0, minute: 0, second: 0)
        let endsAtMidnight = calendar.dateComponents([.hour, .minute, .second], from: rawEndDate)
            == DateComponents(hour: 0, minute: 0, second: 0)
        let isAllDay = ekEvent.isAllDay || (startsAtMidnight && endsAtMidnight && rawEndDate > startDate)

        // 全天事件的結束時間為排他邊界（隔日 00:00）時，往前一秒取得實際結束日
        let inclusiveEndDate: Date = {
            guard isAllDay, endsAtMidnight, rawEndDate > startDate else { return rawEndDate }
            return rawEndDate.addingTimeInterval(-1)
        }()

        let dateString = dateFormatter.string(from: startDate)
        let startTimeString: String
        let endTimeString: String

        if isAllDay {
            startTimeString = "00:00:00"
            endTimeString = "23:59:59"
        } else {
            startTimeString = timeFormatter.string(from: startDate)
            endTimeString = timeFormatter.string(from: inclusiveEndDate)
        }

        let endDateString: String? = calendar.isDate(startDate, inSameDayAs: inclusiveEndDate)
            ? nil
            : dateFormatter.string(from: inclusiveEndDate)

        var information = ""
        if let notes = ekEvent.notes, !notes.isEmpty {
            information = notes
        }
        if let location = ekEvent.location, !location.isEmpty {
            if !information.isEmpty { information += "\n\n" }
            information += "地点：\(location)"
        }

        let createTimeFormatter = DateFormatter.stable("yyyy-MM-dd HH:mm:ss")
        let calendarId = ekEvent.calendar?.calendarIdentifier ?? "apple"
        let appleEventId = ekEvent.eventIdentifier ?? ""

        // 修改内容：Step14 — 重複事件只存母事件一筆，改以 repeatType 表示，
        // 顯示層再展開（原本每次發生各存一筆，資料量與寫入量都被放大）
        let repeatType = Self.repeatType(of: ekEvent)
        let isRecurring = repeatType != "never"

        // 重複事件：唯一鍵不含日期（整個系列一筆）；單次事件維持 occurrence 級唯一鍵
        let occurrenceKey = isRecurring
            ? Event.appleOccurrenceKey(appleEventId: appleEventId, date: "series")
            : Event.appleOccurrenceKey(appleEventId: appleEventId, date: dateString)
        let stableId = Event.appleStableId(occurrenceKey: occurrenceKey)

        // 修改内容：Step19 — 沿用來源日曆顏色，行事曆上以 30% 透明度顯示
        let sourceColorHex = ekEvent.calendar?.cgColor.flatMap { Self.hexString(from: $0) } ?? "#FF6280"

        return Event(
            id: appleEventId.isEmpty ? nil : stableId,
            title: ekEvent.title ?? "未命名事件",
            creatorOpenid: userId,
            color: sourceColorHex,
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
            repeatType: repeatType,   // 修改内容：Step14
            calendarComponent: calendarId,
            appleEventId: appleEventId.isEmpty ? nil : appleEventId,
            appleOccurrenceKey: appleEventId.isEmpty ? nil : occurrenceKey,
            appleCalendarId: calendarId,
            appleCalendarTitle: ekEvent.calendar?.title ?? ""
        )
    }
}
