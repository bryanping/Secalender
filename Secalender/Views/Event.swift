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
    
    // 兼容 SwiftUI ForEach
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
        invitees: [String]? = nil
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
        
    }
    
    // MARK: - Custom Decoding
    enum CodingKeys: String, CodingKey {
        case id, title, creatorOpenid, color, date, startTime, endTime, endDate
        case destination, mapObj, openChecked, personChecked, personNumber
        case sponsorType, category, createTime, deleted, information, groupId
        case isAllDay, repeatType, calendarComponent, travelTime, invitees
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
    }
}

// 辅助扩展
extension Event {
    var dateObj: Date? {
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy"]
        for format in formats {
            let f = DateFormatter()
            f.dateFormat = format
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
            let f = DateFormatter()
            f.dateFormat = format
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
                let f = DateFormatter()
                f.dateFormat = "\(dateFormat) \(timeFormat)"
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
                let f = DateFormatter()
                f.dateFormat = "\(dateFormat) \(timeFormat)"
                if let date = f.date(from: "\(endDateString) \(self.endTime)") {
                    return date
                }
            }
        }
        
        // 如果时间解析失败，尝试只用日期
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy"]
        for format in formats {
            let f = DateFormatter()
            f.dateFormat = format
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

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm" // 根据实际格式调整
    return formatter
}()
