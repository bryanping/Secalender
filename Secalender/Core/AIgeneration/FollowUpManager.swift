//
//  FollowUpManager.swift
//  Secalender
//
//  追问UI状态管理器（C类处理）
//

import Foundation

/// 追问问题类型
enum FollowUpQuestionType {
    case destination      // 去哪里
    case duration         // 计划几天
}

/// 追问状态
struct FollowUpState {
    var currentQuestion: FollowUpQuestionType?
    var questions: [FollowUpQuestionType] = []
    var answers: [FollowUpQuestionType: String] = [:]
    var isComplete: Bool {
        return questions.count == answers.count && questions.count == 2
    }
}

/// 追问管理器
final class FollowUpManager {
    static let shared = FollowUpManager()
    private init() {}
    
    /// 创建C类输入的追问状态（只问2个问题）
    func createFollowUpState() -> FollowUpState {
        var state = FollowUpState()
        // 固定顺序：1. 去哪里  2. 计划几天
        state.questions = [.destination, .duration]
        state.currentQuestion = state.questions.first
        return state
    }
    
    /// 回答问题并移动到下一个问题
    func answerQuestion(_ state: FollowUpState, question: FollowUpQuestionType, answer: String) -> FollowUpState {
        var updated = state
        updated.answers[question] = answer
        
        // 查找下一个未回答的问题
        if let currentIndex = updated.questions.firstIndex(of: question),
           currentIndex + 1 < updated.questions.count {
            updated.currentQuestion = updated.questions[currentIndex + 1]
        } else {
            updated.currentQuestion = nil
        }
        
        return updated
    }
    
    /// 从追问状态构建 ExtractedSlots
    func buildSlotsFromFollowUp(_ state: FollowUpState) -> ExtractedSlots {
        var slots = ExtractedSlots()
        let calendar = Calendar.current
        let today = Date()
        
        // 处理目的地
        if let destination = state.answers[.destination] {
            slots.destination = SlotInfo(value: destination, confidence: 0.9)
        }
        
        // 处理天数
        if let durationText = state.answers[.duration] {
            if let days = parseDuration(durationText) {
                slots.durationDays = SlotInfo(value: days, confidence: 0.9)
                
                // 生成日期范围（默认明天开始）
                if let startDate = calendar.date(byAdding: .day, value: 1, to: today),
                   let endDate = calendar.date(byAdding: .day, value: days - 1, to: startDate) {
                    slots.dateRange = SlotInfo(value: DateRange(startDate: startDate, endDate: endDate), confidence: 0.8)
                }
            }
        }
        
        // 使用默认值补齐偏好
        slots.pace = SlotInfo(value: .moderate, confidence: 0.5)
        slots.walkingLevel = SlotInfo(value: .normal, confidence: 0.5)
        slots.transportPreference = SlotInfo(value: .publicTransport, confidence: 0.5)
        
        return slots
    }
    
    /// 解析天数文本
    private func parseDuration(_ text: String) -> Int? {
        let lowercased = text.lowercased()
        
        // 数字+天
        if let regex = try? NSRegularExpression(pattern: "(\\d+)天", options: []),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)) {
            let range = match.range(at: 1)
            if let swiftRange = Range(range, in: lowercased),
               let days = Int(lowercased[swiftRange]) {
                return days
            }
        }
        
        // 关键词
        if lowercased.contains("1天") || lowercased.contains("一天") || lowercased.contains("1日") || lowercased.contains("一日") {
            return 1
        }
        if lowercased.contains("2天") || lowercased.contains("兩天") || lowercased.contains("两天") || lowercased.contains("2日") || lowercased.contains("二日") {
            return 2
        }
        if lowercased.contains("周末") || lowercased.contains("週末") {
            return 2
        }
        if lowercased.contains("3天") || lowercased.contains("三天") || lowercased.contains("3日") || lowercased.contains("三日") {
            return 3
        }
        
        // 尝试直接解析数字
        if let days = Int(text.trimmingCharacters(in: .whitespaces)) {
            return days
        }
        
        return nil
    }
    
    /// 获取问题的文本
    func getQuestionText(_ question: FollowUpQuestionType) -> String {
        switch question {
        case .destination:
            return "你打算去哪？"
        case .duration:
            return "计划几天？"
        }
    }
    
    /// 获取快捷选项（用于UI显示）
    func getQuickOptions(_ question: FollowUpQuestionType) -> [String] {
        switch question {
        case .destination:
            return ["使用当前定位"]  // UI可以实现为按钮
        case .duration:
            return ["1天", "2天", "周末"]
        }
    }
}
