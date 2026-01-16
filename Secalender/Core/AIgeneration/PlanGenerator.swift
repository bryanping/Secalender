//
//  PlanGenerator.swift
//  Secalender
//
//  行程生成器 - 遵守 TimeBlock、Anchor、缓冲等规则
//

import Foundation
import CoreLocation

/// TimeBlock 类型
enum TimeBlockType: String, Codable {
    case activity = "ACTIVITY"    // 活动
    case transit = "TRANSIT"      // 交通
    case buffer = "BUFFER"        // 缓冲
    case flex = "FLEX"            // 弹性时间
    case rest = "REST"            // 休息
}

/// TimeBlock 结构
struct TimeBlock: Identifiable, Codable {
    let id = UUID()
    var type: TimeBlockType
    var startTime: Date
    var endTime: Date
    var title: String
    var location: String?
    var isAnchor: Bool = false  // 是否为固定锚点
    var priority: Int = 5       // 优先级 1-10，数字越大优先级越高
    var description: String?
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

/// 一天的行程
struct DayPlan: Identifiable, Codable {
    let id = UUID()
    var date: Date
    var blocks: [TimeBlock]
    
    var hasFlex: Bool {
        return blocks.contains { $0.type == .flex }
    }
    
    var hasRest: Bool {
        return blocks.contains { $0.type == .rest }
    }
}

/// 完整行程计划
struct PlanResult: Codable, Identifiable, Equatable {
    let id = UUID()
    let planVersion: String = "1.0"
    var days: [DayPlan]
    var assumptions: [String]      // 默认假设列表
    var riskFlags: [String]        // 风险提示
    
    init(days: [DayPlan] = [], assumptions: [String] = [], riskFlags: [String] = []) {
        self.days = days
        self.assumptions = assumptions
        self.riskFlags = riskFlags
    }
    
    static func == (lhs: PlanResult, rhs: PlanResult) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 行程生成器
final class PlanGenerator {
    static let shared = PlanGenerator()
    private init() {}
    
    // 默认配置
    private let defaultStartTime = (hour: 9, minute: 30)  // 09:30
    private let defaultEndTime = (hour: 20, minute: 30)   // 20:30
    private let defaultActivityDuration: TimeInterval = 90 * 60  // 90分钟
    private let defaultTransitDuration: TimeInterval = 30 * 60   // 30分钟
    private let defaultBufferDuration: TimeInterval = 10 * 60    // 10分钟
    private let maxConsecutiveActivities = 2  // 最多连续2个活动
    private let minFlexDuration: TimeInterval = 30 * 60  // 最少30分钟弹性时间
    private let minRestDuration: TimeInterval = 60 * 60  // 最少60分钟休息时间
    
    /// 生成行程
    func generatePlan(from slots: ExtractedSlots, assumptions: [String] = [], riskFlags: [String] = []) throws -> PlanResult {
        guard let destination = slots.destination.value else {
            throw PlanGenerationError.missingDestination
        }
        
        // 确定日期范围
        let dateRange: DateRange
        if let range = slots.dateRange.value {
            dateRange = range
        } else if let days = slots.durationDays.value {
            let calendar = Calendar.current
            let startDate = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let endDate = calendar.date(byAdding: .day, value: days - 1, to: startDate) ?? startDate
            dateRange = DateRange(startDate: startDate, endDate: endDate)
        } else {
            throw PlanGenerationError.missingDateInfo
        }
        
        // 获取天数
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: dateRange.startDate, to: dateRange.endDate).day ?? 1
        let numberOfDays = max(1, days + 1)
        
        // 生成每天的行程
        var dayPlans: [DayPlan] = []
        
        for dayIndex in 0..<numberOfDays {
            guard let dayDate = calendar.date(byAdding: .day, value: dayIndex, to: dateRange.startDate) else {
                continue
            }
            
            let dayPlan = generateDayPlan(
                date: dayDate,
                dayIndex: dayIndex,
                totalDays: numberOfDays,
                destination: destination,
                slots: slots
            )
            dayPlans.append(dayPlan)
        }
        
        return PlanResult(days: dayPlans, assumptions: assumptions, riskFlags: riskFlags)
    }
    
    /// 生成一天的行程
    private func generateDayPlan(
        date: Date,
        dayIndex: Int,
        totalDays: Int,
        destination: String,
        slots: ExtractedSlots
    ) -> DayPlan {
        let calendar = Calendar.current
        var blocks: [TimeBlock] = []
        
        // 确定一天的开始和结束时间
        var dayStart = calendar.date(bySettingHour: defaultStartTime.hour, minute: defaultStartTime.minute, second: 0, of: date) ?? date
        var dayEnd = calendar.date(bySettingHour: defaultEndTime.hour, minute: defaultEndTime.minute, second: 0, of: date) ?? date
        
        // 应用时间约束
        if let constraints = slots.timeConstraints {
            if constraints.onlyMorning {
                dayEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? dayEnd
            } else if constraints.onlyAfternoon {
                dayStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? dayStart
            } else if constraints.onlyEvening {
                dayStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? dayStart
            }
        }
        
        // 首先处理固定锚点（如果存在）
        var currentTime = dayStart
        var activityCount = 0
        
        // 生成主要活动
        let pace = slots.pace.value ?? .moderate
        let activityDuration = getActivityDuration(for: pace)
        
        // 计算可用时间
        let availableDuration = dayEnd.timeIntervalSince(currentTime)
        let activitiesNeeded = Int(availableDuration / (activityDuration + defaultTransitDuration + defaultBufferDuration))
        let numActivities = min(activitiesNeeded, 4)  // 最多4个主要活动
        
        for i in 0..<numActivities {
            // 检查是否超过连续活动限制
            if activityCount >= maxConsecutiveActivities {
                // 插入休息
                let restEnd = currentTime.addingTimeInterval(minRestDuration)
                if restEnd <= dayEnd {
                    blocks.append(TimeBlock(
                        type: .rest,
                        startTime: currentTime,
                        endTime: restEnd,
                        title: "休息时间",
                        location: nil,
                        isAnchor: false,
                        priority: 3,
                        description: nil
                    ))
                    currentTime = restEnd
                    activityCount = 0
                }
            }
            
            // 添加 TRANSIT（除非是第一个活动）
            if i > 0 {
                let transitEnd = currentTime.addingTimeInterval(defaultTransitDuration)
                if transitEnd <= dayEnd {
                    blocks.append(TimeBlock(
                        type: .transit,
                        startTime: currentTime,
                        endTime: transitEnd,
                        title: "前往下一地点",
                        location: nil,
                        isAnchor: false,
                        priority: 5,
                        description: nil
                    ))
                    currentTime = transitEnd
                }
            }
            
            // 添加 BUFFER
            let bufferEnd = currentTime.addingTimeInterval(defaultBufferDuration)
            if bufferEnd <= dayEnd {
                blocks.append(TimeBlock(
                    type: .buffer,
                    startTime: currentTime,
                    endTime: bufferEnd,
                    title: "缓冲时间",
                    location: nil,
                    isAnchor: false,
                    priority: 4,
                    description: nil
                ))
                currentTime = bufferEnd
            }
            
            // 添加 ACTIVITY
            let activityEnd = currentTime.addingTimeInterval(activityDuration)
            if activityEnd <= dayEnd {
                let activityTitle = generateActivityTitle(dayIndex: dayIndex, activityIndex: i, destination: destination, tags: slots.interestTags)
                
                blocks.append(TimeBlock(
                    type: .activity,
                    startTime: currentTime,
                    endTime: activityEnd,
                    title: activityTitle,
                    location: destination,
                    isAnchor: false,
                    priority: 7,
                    description: generateActivityDescription(tags: slots.interestTags)
                ))
                currentTime = activityEnd
                activityCount += 1
            } else {
                break
            }
        }
        
        // 确保有 FLEX 和 REST
        let remainingTime = dayEnd.timeIntervalSince(currentTime)
        
        if !blocks.contains(where: { $0.type == .flex }) && remainingTime >= minFlexDuration {
            let flexEnd = currentTime.addingTimeInterval(min(minFlexDuration, remainingTime))
            blocks.append(TimeBlock(
                type: .flex,
                startTime: currentTime,
                endTime: flexEnd,
                title: "弹性时间",
                location: nil,
                isAnchor: false,
                priority: 2,
                description: "自由安排"
            ))
            currentTime = flexEnd
        }
        
        if !blocks.contains(where: { $0.type == .rest }) && currentTime < dayEnd {
            let restEnd = min(dayEnd, currentTime.addingTimeInterval(minRestDuration))
            blocks.append(TimeBlock(
                type: .rest,
                startTime: currentTime,
                endTime: restEnd,
                title: "休息时间",
                location: nil,
                isAnchor: false,
                priority: 3,
                description: nil
            ))
        }
        
        // 按时间排序
        blocks.sort { $0.startTime < $1.startTime }
        
        return DayPlan(date: date, blocks: blocks)
    }
    
    /// 根据节奏获取活动时长
    private func getActivityDuration(for pace: Pace) -> TimeInterval {
        switch pace {
        case .relaxed:
            return 120 * 60  // 120分钟
        case .moderate:
            return 90 * 60   // 90分钟
        case .tight:
            return 60 * 60   // 60分钟
        }
    }
    
    /// 生成活动标题
    private func generateActivityTitle(dayIndex: Int, activityIndex: Int, destination: String, tags: [String]) -> String {
        let activities: [String]
        
        if tags.contains("美食") {
            activities = ["\(destination)美食探索", "当地特色餐厅", "品尝地道美食", "美食街巡礼"]
        } else if tags.contains("博物馆") || tags.contains("文化") || tags.contains("历史") {
            activities = ["\(destination)博物馆参观", "历史文化景点", "文化遗址探访", "历史建筑游览"]
        } else if tags.contains("自然") || tags.contains("户外") {
            activities = ["\(destination)自然景观", "户外活动", "自然公园漫步", "自然风光欣赏"]
        } else if tags.contains("购物") {
            activities = ["\(destination)购物中心", "当地市场探索", "特色商店购物", "购物街巡礼"]
        } else if tags.contains("亲子") {
            activities = ["\(destination)亲子乐园", "适合家庭的活动", "亲子互动体验", "儿童友好景点"]
        } else {
            activities = [
                "\(destination)景点参观",
                "\(destination)文化体验",
                "\(destination)休闲活动",
                "\(destination)观光游览",
                "\(destination)探索之旅"
            ]
        }
        
        let index = activityIndex % activities.count
        return activities[index]
    }
    
    /// 生成活动描述
    private func generateActivityDescription(tags: [String]) -> String? {
        if tags.isEmpty {
            return nil
        }
        return "标签：\(tags.joined(separator: ", "))"
    }
    
    /// 将 PlanResult 转换为 ScheduleItem 数组（用于UI展示）
    func convertToScheduleItems(_ plan: PlanResult) -> [ScheduleItem] {
        var items: [ScheduleItem] = []
        
        for day in plan.days {
            for block in day.blocks {
                // 只转换 ACTIVITY 类型的块
                if block.type == .activity {
                    items.append(ScheduleItem(
                        title: block.title,
                        date: day.date,
                        startTime: block.startTime,
                        endTime: block.endTime,
                        location: block.location ?? "",
                        description: block.description ?? ""
                    ))
                }
            }
        }
        
        return items
    }
}

// MARK: - 错误定义

enum PlanGenerationError: LocalizedError {
    case missingDestination
    case missingDateInfo
    case invalidDateRange
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingDestination:
            return "缺少目的地信息"
        case .missingDateInfo:
            return "缺少日期或天数信息"
        case .invalidDateRange:
            return "日期范围无效"
        case .generationFailed(let reason):
            return "行程生成失败：\(reason)"
        }
    }
}
