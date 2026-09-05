//
//  Event.swift
//  Secalender
//
//  Created by linping on 2024/7/9.
//

import Foundation

struct Event: Identifiable, Codable {
    var id: Int?                       // 主键
    var title: String                  // 活动标题
    var creatorOpenid: String          // 创建者 openid
    var color: String                  // 颜色
    var date: String                   // "yyyy-MM-dd" - 開始日期
    var startTime: String              // "HH:mm:ss"
    var endTime: String                // "HH:mm:ss"
    var endDate: String?               // "yyyy-MM-dd" - 結束日期（可選，如果為空則與開始日期相同）
    var destination: String            // 地点
    var mapObj: String                 // 地图对象，JSON 字符串
    var openChecked: Int               // 是否公开
    var personChecked: Int             // 是否实名
    var personNumber: Int?             // 人数
    var sponsorType: String?           // 主办类型
    var category: String?              // 分类
    var createTime: String             // "yyyy-MM-dd HH:mm:ss"
    var deleted: Int?                  // 是否删除
    var information: String?           // 备注信息
    var groupId: String?               // 新增屬性對應所屬社群（若非社群活動則為 nil）


    var isAllDay: Bool? = false         // 是否整日活動
    var repeatType: String? = "never"   // 重複類型: never, daily, weekly, monthly, yearly
    var calendarComponent: String? = "default" // 行事曆組件
    var travelTime: String?            // 路程時間
    var invitees: [String]?            // 邀請對象
    var aiEvent: Int? = 0              // 智能行程标识：0=普通行程，1=智能行程（AI生成）
    var tags: [String]?                // 事件標籤，用於分類與搜尋

    // 修改内容：Apple 匯入 Step1 — 匯入來源識別，供去重與管理頁使用
    var appleEventId: String?          // Apple 日曆事件識別符（EKEvent.eventIdentifier）
    var appleOccurrenceKey: String?    // "appleEventId|yyyy-MM-dd"，重複事件單次發生的唯一鍵
    var appleCalendarId: String?       // 來源 Apple 日曆識別符
    var appleCalendarTitle: String?    // 來源 Apple 日曆名稱
    var timeItemId: String?            // 修改内容：Step8 — 來源 time_items 文件 id（供刪除回寫）

    // MARK: - 同步欄位（Local First，對應 OFFLINE_SYNC_DESIGN.md）
    var syncStatusRaw: String?        // SyncStatus.rawValue，可選以相容舊快取
    var updatedAtSync: Date?          // 本地最後修改時間（用於衝突判定）
    var serverUpdatedAt: Date?        // 伺服器版本時間
    var syncVersion: Int?             // 版本號
    var deviceId: String?             // 來源裝置
    var lastEditorId: String?         // 最後修改者
    var uuid: UUID { UUID() }
    
    init(
        id: Int? = nil,
        title: String = "",
        creatorOpenid: String = "",
        color: String = "",
        date: String = "",
        startTime: String = "",
        endTime: String = "",
        endDate: String? = nil,
        destination: String = "",
        mapObj: String = "",
        openChecked: Int = 0,
        personChecked: Int = 0,
        personNumber: Int? = nil,
        sponsorType: String? = nil,
        category: String? = nil,
        createTime: String = "",
        deleted: Int? = nil,
        information: String? = nil,
        isAllDay: Bool = false,
        repeatType: String = "never",
        calendarComponent: String = "default",
        travelTime: String? = nil,
        groupId: String? = nil,
        invitees: [String]? = nil,
        aiEvent: Int? = 0,
        tags: [String]? = nil,
        appleEventId: String? = nil,           // 修改内容：Apple 匯入 Step1
        appleOccurrenceKey: String? = nil,     // 修改内容：Apple 匯入 Step1
        appleCalendarId: String? = nil,        // 修改内容：Apple 匯入 Step1
        appleCalendarTitle: String? = nil,     // 修改内容：Apple 匯入 Step1
        timeItemId: String? = nil,             // 修改内容：Step8
        syncStatusRaw: String? = nil,
        updatedAtSync: Date? = nil,
        serverUpdatedAt: Date? = nil,
        syncVersion: Int? = nil,
        deviceId: String? = nil,
        lastEditorId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.creatorOpenid = creatorOpenid
        self.color = color
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.endDate = endDate
        self.destination = destination
        self.mapObj = mapObj
        self.openChecked = openChecked
        self.personChecked = personChecked
        self.personNumber = personNumber
        self.sponsorType = sponsorType
        self.category = category
        self.createTime = createTime
        self.deleted = deleted
        self.information = information
        self.isAllDay = isAllDay
        self.repeatType = repeatType
        self.calendarComponent = calendarComponent
        self.travelTime = travelTime
        self.groupId = groupId
        self.invitees = invitees
        self.aiEvent = aiEvent
        self.tags = tags
        self.appleEventId = appleEventId                 // 修改内容：Apple 匯入 Step1
        self.appleOccurrenceKey = appleOccurrenceKey     // 修改内容：Apple 匯入 Step1
        self.appleCalendarId = appleCalendarId           // 修改内容：Apple 匯入 Step1
        self.appleCalendarTitle = appleCalendarTitle     // 修改内容：Apple 匯入 Step1
        self.timeItemId = timeItemId                     // 修改内容：Step8
        self.syncStatusRaw = syncStatusRaw
        self.updatedAtSync = updatedAtSync
        self.serverUpdatedAt = serverUpdatedAt
        self.syncVersion = syncVersion
        self.deviceId = deviceId
        self.lastEditorId = lastEditorId
    }
    
    // MARK: - Custom Decoding
    enum CodingKeys: String, CodingKey {
        case id, title, creatorOpenid, color, date, startTime, endTime, endDate
        case destination, mapObj, openChecked, personChecked, personNumber
        case sponsorType, category, createTime, deleted, information, groupId
        case isAllDay, repeatType, calendarComponent, travelTime, invitees, aiEvent, tags
        case appleEventId, appleOccurrenceKey, appleCalendarId, appleCalendarTitle  // 修改内容：Apple 匯入 Step1
        case timeItemId  // 修改内容：Step8
        case syncStatusRaw, updatedAtSync, serverUpdatedAt, syncVersion, deviceId, lastEditorId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 处理可能缺失的字段
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        creatorOpenid = try container.decodeIfPresent(String.self, forKey: .creatorOpenid) ?? ""
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#FF0000" // 默认红色
        
        // 处理date字段：优先尝试String，如果失败则尝试其他类型
        if let dateString = try? container.decode(String.self, forKey: .date) {
            date = dateString
        } else {
            // 如果解码失败，使用空字符串（会在EventManager中手动处理）
            date = ""
        }
        
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime) ?? ""
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime) ?? ""
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
        mapObj = try container.decodeIfPresent(String.self, forKey: .mapObj) ?? ""
        openChecked = try container.decodeIfPresent(Int.self, forKey: .openChecked) ?? 0
        personChecked = try container.decodeIfPresent(Int.self, forKey: .personChecked) ?? 0
        personNumber = try container.decodeIfPresent(Int.self, forKey: .personNumber)
        sponsorType = try container.decodeIfPresent(String.self, forKey: .sponsorType)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        createTime = try container.decodeIfPresent(String.self, forKey: .createTime) ?? ""
        deleted = try container.decodeIfPresent(Int.self, forKey: .deleted)
        information = try container.decodeIfPresent(String.self, forKey: .information)
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        repeatType = try container.decodeIfPresent(String.self, forKey: .repeatType) ?? "never"
        calendarComponent = try container.decodeIfPresent(String.self, forKey: .calendarComponent) ?? "default"
        travelTime = try container.decodeIfPresent(String.self, forKey: .travelTime)
        invitees = try container.decodeIfPresent([String].self, forKey: .invitees)
        aiEvent = try container.decodeIfPresent(Int.self, forKey: .aiEvent) ?? 0
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        // 修改内容：Apple 匯入 Step1
        appleEventId = try container.decodeIfPresent(String.self, forKey: .appleEventId)
        appleOccurrenceKey = try container.decodeIfPresent(String.self, forKey: .appleOccurrenceKey)
        appleCalendarId = try container.decodeIfPresent(String.self, forKey: .appleCalendarId)
        appleCalendarTitle = try container.decodeIfPresent(String.self, forKey: .appleCalendarTitle)
        timeItemId = try container.decodeIfPresent(String.self, forKey: .timeItemId)
        syncStatusRaw = try container.decodeIfPresent(String.self, forKey: .syncStatusRaw)
        updatedAtSync = try container.decodeIfPresent(Date.self, forKey: .updatedAtSync)
        serverUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .serverUpdatedAt)
        syncVersion = try container.decodeIfPresent(Int.self, forKey: .syncVersion)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        lastEditorId = try container.decodeIfPresent(String.self, forKey: .lastEditorId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(creatorOpenid, forKey: .creatorOpenid)
        try container.encode(color, forKey: .color)
        try container.encode(date, forKey: .date)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(destination, forKey: .destination)
        try container.encode(mapObj, forKey: .mapObj)
        try container.encode(openChecked, forKey: .openChecked)
        try container.encode(personChecked, forKey: .personChecked)
        try container.encodeIfPresent(personNumber, forKey: .personNumber)
        try container.encodeIfPresent(sponsorType, forKey: .sponsorType)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(createTime, forKey: .createTime)
        try container.encodeIfPresent(deleted, forKey: .deleted)
        try container.encodeIfPresent(information, forKey: .information)
        try container.encodeIfPresent(groupId, forKey: .groupId)
        try container.encodeIfPresent(isAllDay, forKey: .isAllDay)
        try container.encodeIfPresent(repeatType, forKey: .repeatType)
        try container.encodeIfPresent(calendarComponent, forKey: .calendarComponent)
        try container.encodeIfPresent(travelTime, forKey: .travelTime)
        try container.encodeIfPresent(invitees, forKey: .invitees)
        try container.encodeIfPresent(aiEvent, forKey: .aiEvent)
        try container.encodeIfPresent(tags, forKey: .tags)
        // 修改内容：Apple 匯入 Step1
        try container.encodeIfPresent(appleEventId, forKey: .appleEventId)
        try container.encodeIfPresent(appleOccurrenceKey, forKey: .appleOccurrenceKey)
        try container.encodeIfPresent(appleCalendarId, forKey: .appleCalendarId)
        try container.encodeIfPresent(appleCalendarTitle, forKey: .appleCalendarTitle)
        try container.encodeIfPresent(timeItemId, forKey: .timeItemId)
        try container.encodeIfPresent(syncStatusRaw, forKey: .syncStatusRaw)
        try container.encodeIfPresent(updatedAtSync, forKey: .updatedAtSync)
        try container.encodeIfPresent(serverUpdatedAt, forKey: .serverUpdatedAt)
        try container.encodeIfPresent(syncVersion, forKey: .syncVersion)
        try container.encodeIfPresent(deviceId, forKey: .deviceId)
        try container.encodeIfPresent(lastEditorId, forKey: .lastEditorId)
    }
}

// 辅助扩展
extension Event {
    /// 從 TimeItem 轉換為 Event（用於 CalendarView 漸進式遷移顯示）
    static func from(timeItem: TimeItem, creatorOpenid: String) -> Event? {
        guard timeItem.type == .event || timeItem.type == .suggestion,
              let startAt = timeItem.startAt, let endAt = timeItem.endAt else { return nil }
        let df = DateFormatter.stable("yyyy-MM-dd")
        let tf = DateFormatter.stable("HH:mm:ss")
        let dateStr = df.string(from: startAt)
        let startTimeStr = tf.string(from: startAt)
        let endTimeStr = tf.string(from: endAt)
        let endDateStr = df.string(from: endAt)
        let createStr = timeItem.createdAt.map { df.string(from: $0) + " " + tf.string(from: $0) } ?? ""
        // 修改内容：P0-3 — 改用穩定雜湊，跨啟動不變
        let idFromHash = -1_000_000 - ((timeItem.id ?? UUID().uuidString).stableIntId % 1_000_000)
        return Event(
            id: idFromHash,
            title: timeItem.title,
            creatorOpenid: creatorOpenid,
            color: timeItem.type == .suggestion ? "#9E9E9E" : "#007AFF",
            date: dateStr,
            startTime: startTimeStr,
            endTime: endTimeStr,
            endDate: dateStr != endDateStr ? endDateStr : nil,
            destination: timeItem.notes ?? "",
            mapObj: "{}",
            openChecked: 0,
            personChecked: 0,
            createTime: createStr,
            information: timeItem.notes,
            aiEvent: timeItem.source == .ai ? 1 : 0,
            timeItemId: timeItem.id   // 修改内容：Step8 — 保留來源 id，刪除時可回寫 time_items
        )
    }
    
    // MARK: - 修改内容：Apple 匯入 Step1 — 穩定身分（去重核心）
    /// 由 Apple 事件識別符 + 發生日期組成的唯一鍵（重複事件每次發生各一筆）
    static func appleOccurrenceKey(appleEventId: String, date: String) -> String {
        "\(appleEventId)|\(date)"
    }

    /// 由 occurrenceKey 推導的穩定本地 id（跨啟動、跨重裝一致）
    /// 區段 -3,000,000 ~ -3,999,999，與 TimeItem（-1,xxx,xxx）不重疊
    static func appleStableId(occurrenceKey: String) -> Int {
        -3_000_000 - (occurrenceKey.stableIntId % 1_000_000)
    }

    /// 是否為 Apple 日曆匯入
    var isAppleImported: Bool { appleEventId != nil }

    /// 修改内容：Apple 同步 Step7 — 行程來源名稱（編輯頁顯示）
    /// 有同步來源時回傳日曆名稱，否則回傳 nil（代表 App 內建立）
    var importSourceName: String? {
        if let title = appleCalendarTitle, !title.isEmpty { return title }
        guard let comp = calendarComponent, comp != "default", comp != "event", !comp.isEmpty else { return nil }
        if let ekTitle = AppleCalendarManager.shared.calendar(withIdentifier: comp)?.title { return ekTitle }
        return isAppleImported ? "Apple 日曆" : nil
    }

    /// 是否為外部匯入（Apple Calendar / Google Calendar）
    var isFromExternalImport: Bool {
        guard let comp = calendarComponent, !comp.isEmpty else { return false }
        return comp != "default" && comp != "event"
    }
    
    /// 是否為跨日/多日活動（開始與結束日期不同天）
    var isMultiDay: Bool {
        guard let start = dateObj else { return false }
        guard let end = endDateObj else { return false }
        return Calendar.current.compare(start, to: end, toGranularity: .day) != .orderedSame
    }
    
    var dateObj: Date? {
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy"]
        for format in formats {
            let f = DateFormatter.stable(format)  // 修改内容：Phase 1-A
            if let date = f.date(from: self.date) {
                return date
            }
        }
        return nil
    }
    
    var endDateObj: Date? {
        guard let endDate = self.endDate else { return nil }
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy"]
        for format in formats {
            let f = DateFormatter.stable(format)  // 修改内容：Phase 1-A
            if let date = f.date(from: endDate) {
                return date
            }
        }
        return nil
    }
    
    var startDateTime: Date? {
        // 支持多种时间格式
        let timeFormats = ["HH:mm:ss", "HH:mm", "H:mm", "h:mm a", "h:mm:ss a"]
        let dateFormats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy"]
        
        for dateFormat in dateFormats {
            for timeFormat in timeFormats {
                let f = DateFormatter.stable("\(dateFormat) \(timeFormat)")  // 修改内容：Phase 1-A
                if let date = f.date(from: "\(self.date) \(self.startTime)") {
                    return date
                }
            }
        }
        
        // 如果时间解析失败，尝试只用日期
        if let dateOnly = dateObj {
            let calendar = Calendar.current
            let timeComponents = startTime.split(separator: ":").compactMap { Int($0) }
            if timeComponents.count >= 2 {
                var components = calendar.dateComponents([.year, .month, .day], from: dateOnly)
                components.hour = timeComponents[0]
                components.minute = timeComponents[1]
                components.second = timeComponents.count > 2 ? timeComponents[2] : 0
                return calendar.date(from: components)
            }
        }
        
        return nil
    }
    
    var endDateTime: Date? {
        // 使用結束日期（如果有的話），否則使用開始日期
        let endDateString = self.endDate ?? self.date
        
        // 支持多种时间格式
        let timeFormats = ["HH:mm:ss", "HH:mm", "H:mm", "h:mm a", "h:mm:ss a"]
        let dateFormats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy"]
        
        for dateFormat in dateFormats {
            for timeFormat in timeFormats {
                let f = DateFormatter.stable("\(dateFormat) \(timeFormat)")  // 修改内容：Phase 1-A
                if let date = f.date(from: "\(endDateString) \(self.endTime)") {
                    return date
                }
            }
        }
        
        // 如果时间解析失败，尝试只用日期
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy"]
        for format in formats {
            let f = DateFormatter.stable(format)  // 修改内容：Phase 1-A
            if let dateOnly = f.date(from: endDateString) {
                let calendar = Calendar.current
                let timeComponents = endTime.split(separator: ":").compactMap { Int($0) }
                if timeComponents.count >= 2 {
                    var components = calendar.dateComponents([.year, .month, .day], from: dateOnly)
                    components.hour = timeComponents[0]
                    components.minute = timeComponents[1]
                    components.second = timeComponents.count > 2 ? timeComponents[2] : 0
                    return calendar.date(from: components)
                }
            }
        }
        
        return nil
    }
    
    var isOpenChecked: Bool { self.openChecked == 1 }
    var isPersonChecked: Bool { self.personChecked == 1 }
    var isAiEvent: Bool { (self.aiEvent ?? 0) == 1 }  // 是否为智能行程

    /// 同步狀態（由 syncStatusRaw 解析，無則視為 .synced）
    var syncStatus: SyncStatus {
        get {
            guard let raw = syncStatusRaw, let s = SyncStatus(rawValue: raw) else { return .synced }
            return s
        }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    /// 推断是否有结束时间（用于 UI 显示）
    /// isHasEnd 是一个 UI 状态，不需要存储到 Firebase
    /// 它可以从 endTime 和 endDate 推断出来
    var inferredIsHasEnd: Bool {
        // 如果是整日活动，没有结束时间
        if isAllDay == true {
            return false
        }
        // 如果有结束日期且不等于开始日期，则认为有结束时间
        if let endDate = endDate, endDate != date {
            return true
        }
        // 如果有结束时间且不等于开始时间，则认为有结束时间
        if !endTime.isEmpty && endTime != startTime {
            return true
        }
        return false
    }
}

// MARK: - 事件標籤預設選項（用於建立/編輯/搜尋）
enum EventTagPresets {
    static let defaultTags: [(key: String, localizedKey: String)] = [
        ("work", "event_tags.work"),
        ("travel", "event_tags.travel"),
        ("sport", "event_tags.sport"),
        ("meetup", "event_tags.meetup"),
        ("study", "event_tags.study"),
        ("other", "event_tags.other")
    ]
    
    static var tagKeys: [String] { defaultTags.map(\.key) }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter.stable("HH:mm")
    return formatter
}()

// MARK: - Stable ID（P0-3）
// 修改内容：Swift 的 hashValue 每次 App 啟動隨機化（seed randomization），
// 不可作為持久化 ID。改用 djb2 穩定雜湊，同一字串在任何啟動/裝置上結果相同。
// TODO(Phase 1)：事件 id 全面遷移為 documentID 字串後移除整個 Int id 體系。
extension String {
    var stableIntId: Int {
        var hash: UInt64 = 5381
        for b in utf8 { hash = (hash &* 33) &+ UInt64(b) }
        return Int(hash & 0x7fff_ffff_ffff)
    }
}

// MARK: - 修改内容：Phase 2-B — 重複事件展開引擎（v1：顯示層展開）
// repeatType（never/daily/weekly/monthly/yearly）此前只有欄位無任何消費端。
// v1 於日曆載入範圍內展開虛擬 occurrence（同 id、日期平移）；
// 編輯/刪除仍作用於母事件（「僅此次/此後全部」語意留待 v2）。
extension Event {
    var isRepeating: Bool {
        guard let r = repeatType else { return false }
        return r != "never" && !r.isEmpty
    }

    /// 展開與 [rangeStart, rangeEnd] 重疊的重複發生（不含母事件本身）
    func occurrences(from rangeStart: Date, to rangeEnd: Date, calendar: Calendar = .current) -> [Event] {
        guard isRepeating, let baseStart = dateObj else { return [] }

        let baseDay = calendar.startOfDay(for: baseStart)
        var spanDays = 0
        if let end = endDateObj {
            spanDays = max(0, calendar.dateComponents([.day], from: baseDay, to: calendar.startOfDay(for: end)).day ?? 0)
        }

        let step: DateComponents
        switch repeatType {
        case "daily": step = DateComponents(day: 1)
        case "weekly": step = DateComponents(day: 7)
        case "monthly": step = DateComponents(month: 1)
        case "yearly": step = DateComponents(year: 1)
        default: return []
        }

        let df = DateFormatter.stable("yyyy-MM-dd")
        var result: [Event] = []
        var occStart = baseDay
        var guardCount = 0
        while occStart <= rangeEnd && guardCount < 1000 {
            guardCount += 1
            let occEnd = calendar.date(byAdding: .day, value: spanDays, to: occStart) ?? occStart
            if occStart > baseDay && occStart <= rangeEnd && occEnd >= rangeStart {
                var copy = self
                copy.date = df.string(from: occStart)
                copy.endDate = spanDays > 0 ? df.string(from: occEnd) : nil
                result.append(copy)
            }
            guard let next = calendar.date(byAdding: step, to: occStart) else { break }
            occStart = next
        }
        return result
    }
}
