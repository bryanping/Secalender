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

    var isAllDay: Bool = false         // 是否整日活動
    var repeatType: String = "never"   // 重複類型: never, daily, weekly, monthly, yearly
    var calendarComponent: String = "default" // 行事曆組件
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
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm" // 根据实际格式调整
    return formatter
}()
