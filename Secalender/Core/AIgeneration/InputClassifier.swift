//
//  InputClassifier.swift
//  Secalender
//
//  需求输入判别器 - 实现 A/B/C/D 分类
//

import Foundation

/// 输入类型枚举
enum InputType {
    case typeA    // 完整需求 - 直接生成
    case typeB    // 半需求 - 默认值补齐后生成
    case typeC    // 碎片/无效需求 - 最少追问
    case typeD    // 模板意图 - 切换到模板系统
}

/// Slot 信息结构（带置信度）
struct SlotInfo<T> {
    let value: T?
    let confidence: Double  // 0.0 ~ 1.0
}

/// 抽取的关键信息
struct ExtractedSlots {
    // 必须字段
    var destination: SlotInfo<String> = SlotInfo(value: nil, confidence: 0.0)
    var dateRange: SlotInfo<DateRange> = SlotInfo(value: nil, confidence: 0.0)
    var durationDays: SlotInfo<Int> = SlotInfo(value: nil, confidence: 0.0)
    
    // 强约束字段
    var startLocation: SlotInfo<String> = SlotInfo(value: nil, confidence: 0.0)
    var fixedAnchors: [FixedAnchor] = []
    var timeConstraints: TimeConstraints? = nil
    
    // 偏好字段
    var pace: SlotInfo<Pace> = SlotInfo(value: nil, confidence: 0.0)
    var walkingLevel: SlotInfo<WalkingLevel> = SlotInfo(value: nil, confidence: 0.0)
    var budgetLevel: SlotInfo<BudgetLevel> = SlotInfo(value: nil, confidence: 0.0)
    var interestTags: [String] = []
    var transportPreference: SlotInfo<TransportPreference> = SlotInfo(value: nil, confidence: 0.0)
}

/// 日期范围
struct DateRange {
    let startDate: Date
    let endDate: Date
}

/// 固定锚点（会议、门票、班次等）
struct FixedAnchor {
    let title: String
    let date: Date
    let startTime: Date
    let endTime: Date
    let location: String?
}

/// 时间约束
struct TimeConstraints {
    var onlyMorning: Bool = false
    var onlyAfternoon: Bool = false
    var onlyEvening: Bool = false
}

/// 节奏类型
enum Pace: String, CaseIterable {
    case relaxed = "松"
    case moderate = "中"
    case tight = "紧"
}

/// 步行强度
enum WalkingLevel: String, CaseIterable {
    case low = "少走路"
    case normal = "正常"
    case high = "可多走"
}

/// 预算级别
enum BudgetLevel: String, CaseIterable {
    case low = "低"
    case moderate = "中"
    case high = "高"
}

/// 交通偏好
enum TransportPreference: String, CaseIterable {
    case publicTransport = "公共交通"
    case taxi = "出租车"
    case walking = "步行"
    case mixed = "混合"
}

/// 需求判别结果
struct ClassificationResult {
    let inputType: InputType
    let slots: ExtractedSlots
    let assumptions: [String]  // 默认假设列表
    let riskFlags: [String]    // 风险提示
}

/// 需求输入判别器
final class InputClassifier {
    static let shared = InputClassifier()
    private init() {}
    
    /// 判别流程（强制顺序执行）
    func classify(_ input: String) -> ClassificationResult {
        // 1. 文本预处理
        let cleaned = preprocess(input)
        
        // 2. 输入类型判别（A/B/C/D）
        let inputType = determineInputType(cleaned)
        
        // 3. 关键信息抽取（Slot Filling）
        var slots = extractSlots(cleaned)
        
        // 4. 缺失字段补齐或追问决策
        var assumptions: [String] = []
        var riskFlags: [String] = []
        
        if inputType == .typeB {
            (slots, assumptions) = fillDefaults(slots)
        } else if inputType == .typeC {
            riskFlags.append("输入信息不完整，需要追问")
        }
        
        // 5. 验证风险
        riskFlags.append(contentsOf: validateRisks(slots))
        
        return ClassificationResult(
            inputType: inputType,
            slots: slots,
            assumptions: assumptions,
            riskFlags: riskFlags
        )
    }
    
    // MARK: - 文本预处理
    
    private func preprocess(_ text: String) -> String {
        // 清洗：去除多余空格、换行
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // 长度判断（极短文本标记为可能无效）
        if cleaned.count <= 3 {
            return cleaned  // 标记为可能的 C 类
        }
        
        return cleaned
    }
    
    // MARK: - 输入类型判别
    
    private func determineInputType(_ text: String) -> InputType {
        let lowercased = text.lowercased()
        
        // D 类：模板意图（优先级最高）
        let templateKeywords = ["模板", "套用", "类似", "参考", "跟上次一样", "跟上次", "一樣", "一樣的"]
        for keyword in templateKeywords {
            if lowercased.contains(keyword) {
                return .typeD
            }
        }
        
        // 极短文本 -> C 类
        if text.count <= 3 {
            return .typeC
        }
        
        // 尝试抽取关键信息
        let slots = extractSlots(text)
        
        // 计算关键字段完整度
        var filledCount = 0
        let totalRequired = 3  // 目的地、时间、意图
        
        if slots.destination.value != nil && slots.destination.confidence > 0.5 {
            filledCount += 1
        }
        if (slots.dateRange.value != nil || slots.durationDays.value != nil) &&
           (slots.dateRange.confidence > 0.5 || slots.durationDays.confidence > 0.5) {
            filledCount += 1
        }
        if slots.interestTags.count > 0 || 
           slots.pace.value != nil ||
           slots.walkingLevel.value != nil {
            filledCount += 1
        }
        
        // A 类：至少 2 个关键字段
        if filledCount >= 2 {
            return .typeA
        }
        
        // B 类：至少有目的地或意图
        if filledCount >= 1 {
            return .typeB
        }
        
        // C 类：其他情况
        return .typeC
    }
    
    // MARK: - Slot Filling
    
    private func extractSlots(_ text: String) -> ExtractedSlots {
        var slots = ExtractedSlots()
        let lowercased = text.lowercased()
        
        // 抽取目的地
        slots.destination = extractDestination(text, lowercased)
        
        // 抽取日期/天数
        let dateInfo = extractDateInfo(text, lowercased)
        slots.dateRange = dateInfo.range
        slots.durationDays = dateInfo.duration
        
        // 抽取时间约束
        slots.timeConstraints = extractTimeConstraints(lowercased)
        
        // 抽取偏好
        slots.pace = extractPace(lowercased)
        slots.walkingLevel = extractWalkingLevel(lowercased)
        slots.budgetLevel = extractBudgetLevel(lowercased)
        slots.transportPreference = extractTransportPreference(lowercased)
        
        // 抽取兴趣标签
        slots.interestTags = extractInterestTags(lowercased)
        
        return slots
    }
    
    // MARK: - 具体字段抽取方法
    
    private func extractDestination(_ text: String, _ lowercased: String) -> SlotInfo<String> {
        // 城市关键词列表
        let cityKeywords = [
            "台北", "台東", "台南", "台中", "高雄", "新北", "桃園", "新竹", "基隆",
            "台北市", "台東市", "台南市", "台中市", "高雄市", "新北市", "桃園市", "新竹市", "基隆市",
            "京都", "東京", "大阪", "名古屋", "札幌", "福岡", "沖繩", "日本",
            "首爾", "釜山", "韓國", "韓國",
            "上海", "北京", "廣州", "深圳", "杭州", "成都", "重慶", "中國",
            "香港", "澳門",
            "新加坡", "曼谷", "清邁", "泰國",
            "巴黎", "倫敦", "紐約", "洛杉磯", "舊金山", "西雅圖"
        ]
        
        for city in cityKeywords {
            if lowercased.contains(city.lowercased()) {
                return SlotInfo(value: city, confidence: 0.8)
            }
        }
        
        // 如果包含"行程"、"遊"、"玩"等词，尝试抽取前面的地名
        let patterns = [
            "(.+)行程",
            "(.+)遊",
            "去(.+)",
            "(.+)玩",
            "(.+)旅遊"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: text) {
                    let extracted = String(text[swiftRange]).trimmingCharacters(in: .whitespaces)
                    if extracted.count > 0 && extracted.count < 20 {
                        return SlotInfo(value: extracted, confidence: 0.6)
                    }
                }
            }
        }
        
        return SlotInfo(value: nil, confidence: 0.0)
    }
    
    private func extractDateInfo(_ text: String, _ lowercased: String) -> (range: SlotInfo<DateRange>, duration: SlotInfo<Int>) {
        var dateRange: SlotInfo<DateRange> = SlotInfo(value: nil, confidence: 0.0)
        var duration: SlotInfo<Int> = SlotInfo(value: nil, confidence: 0.0)
        
        let calendar = Calendar.current
        let today = Date()
        
        // 抽取天数（优先级高）
        let dayPatterns = [
            (pattern: "(\\d+)天", multiplier: 1),
            (pattern: "(\\d+)日", multiplier: 1),
            (pattern: "一天", multiplier: 1),
            (pattern: "兩天", multiplier: 2),
            (pattern: "兩天一夜", multiplier: 2),
            (pattern: "三天", multiplier: 3),
            (pattern: "三天兩夜", multiplier: 3),
            (pattern: "四天", multiplier: 4),
            (pattern: "五天", multiplier: 5),
            (pattern: "一日", multiplier: 1),
            (pattern: "一日遊", multiplier: 1),
            (pattern: "二日", multiplier: 2),
            (pattern: "三日", multiplier: 3)
        ]
        
        for (pattern, multiplier) in dayPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)) {
                if pattern.contains("\\d+") {
                    let range = match.range(at: 1)
                    if let swiftRange = Range(range, in: lowercased),
                       let days = Int(lowercased[swiftRange]) {
                        duration = SlotInfo(value: days * multiplier, confidence: 0.9)
                        break
                    }
                } else {
                    duration = SlotInfo(value: multiplier, confidence: 0.9)
                    break
                }
            }
        }
        
        // 抽取日期关键词
        if lowercased.contains("周末") || lowercased.contains("週末") {
            // 计算下个周末
            let weekday = calendar.component(.weekday, from: today)
            let daysUntilSaturday = (7 - weekday + 1) % 7
            if daysUntilSaturday == 0 {
                // 今天就是周六
                if let saturday = calendar.date(byAdding: .day, value: 0, to: today),
                   let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) {
                    dateRange = SlotInfo(value: DateRange(startDate: saturday, endDate: sunday), confidence: 0.8)
                    duration = SlotInfo(value: 2, confidence: 0.8)
                }
            } else {
                if let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: today),
                   let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) {
                    dateRange = SlotInfo(value: DateRange(startDate: saturday, endDate: sunday), confidence: 0.8)
                    duration = SlotInfo(value: 2, confidence: 0.8)
                }
            }
        } else if lowercased.contains("明天") || lowercased.contains("明日") {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
                dateRange = SlotInfo(value: DateRange(startDate: tomorrow, endDate: tomorrow), confidence: 0.9)
                duration = SlotInfo(value: 1, confidence: 0.9)
            }
        } else if lowercased.contains("今天") || lowercased.contains("今日") {
            dateRange = SlotInfo(value: DateRange(startDate: today, endDate: today), confidence: 0.9)
            duration = SlotInfo(value: 1, confidence: 0.9)
        }
        
        // 如果抽取到天数但没有日期范围，根据天数生成日期范围
        if duration.value != nil && dateRange.value == nil {
            let days = duration.value ?? 1
            if let startDate = calendar.date(byAdding: .day, value: 1, to: today), // 默认明天开始
               let endDate = calendar.date(byAdding: .day, value: days - 1, to: startDate) {
                dateRange = SlotInfo(value: DateRange(startDate: startDate, endDate: endDate), confidence: duration.confidence * 0.7)
            }
        }
        
        return (dateRange, duration)
    }
    
    private func extractTimeConstraints(_ lowercased: String) -> TimeConstraints? {
        var constraints = TimeConstraints()
        
        if lowercased.contains("只上午") || lowercased.contains("僅上午") || lowercased.contains("上午") {
            constraints.onlyMorning = true
        }
        if lowercased.contains("只下午") || lowercased.contains("僅下午") || lowercased.contains("下午") {
            constraints.onlyAfternoon = true
        }
        if lowercased.contains("只晚上") || lowercased.contains("僅晚上") || lowercased.contains("晚上") {
            constraints.onlyEvening = true
        }
        
        if constraints.onlyMorning || constraints.onlyAfternoon || constraints.onlyEvening {
            return constraints
        }
        
        return nil
    }
    
    private func extractPace(_ lowercased: String) -> SlotInfo<Pace> {
        if lowercased.contains("不要太累") || lowercased.contains("輕鬆") || lowercased.contains("輕鬆") || lowercased.contains("松") {
            return SlotInfo(value: .relaxed, confidence: 0.8)
        }
        if lowercased.contains("緊湊") || lowercased.contains("緊") || lowercased.contains("趕") {
            return SlotInfo(value: .tight, confidence: 0.8)
        }
        return SlotInfo(value: nil, confidence: 0.0)
    }
    
    private func extractWalkingLevel(_ lowercased: String) -> SlotInfo<WalkingLevel> {
        if lowercased.contains("少走路") || lowercased.contains("不想走路") || lowercased.contains("不要走") {
            return SlotInfo(value: .low, confidence: 0.9)
        }
        if lowercased.contains("多走") || lowercased.contains("走路") {
            return SlotInfo(value: .high, confidence: 0.8)
        }
        return SlotInfo(value: nil, confidence: 0.0)
    }
    
    private func extractBudgetLevel(_ lowercased: String) -> SlotInfo<BudgetLevel> {
        if lowercased.contains("預算低") || lowercased.contains("便宜") || lowercased.contains("省錢") {
            return SlotInfo(value: .low, confidence: 0.8)
        }
        if lowercased.contains("預算高") || lowercased.contains("豪華") || lowercased.contains("奢華") {
            return SlotInfo(value: .high, confidence: 0.8)
        }
        return SlotInfo(value: nil, confidence: 0.0)
    }
    
    private func extractTransportPreference(_ lowercased: String) -> SlotInfo<TransportPreference> {
        if lowercased.contains("地鐵") || lowercased.contains("捷運") || lowercased.contains("公交") || lowercased.contains("公車") {
            return SlotInfo(value: .publicTransport, confidence: 0.8)
        }
        if lowercased.contains("計程車") || lowercased.contains("的士") || lowercased.contains("taxi") {
            return SlotInfo(value: .taxi, confidence: 0.8)
        }
        if lowercased.contains("步行") || lowercased.contains("走路") {
            return SlotInfo(value: .walking, confidence: 0.8)
        }
        return SlotInfo(value: nil, confidence: 0.0)
    }
    
    private func extractInterestTags(_ lowercased: String) -> [String] {
        var tags: [String] = []
        
        let tagKeywords: [String: String] = [
            "親子": "亲子",
            "美食": "美食",
            "博物館": "博物馆",
            "自然": "自然",
            "購物": "购物",
            "文化": "文化",
            "歷史": "历史",
            "藝術": "艺术",
            "戶外": "户外",
            "娛樂": "娱乐",
            "度假": "度假",
            "商務": "商务",
            "出差": "商务"
        ]
        
        for (key, value) in tagKeywords {
            if lowercased.contains(key) || lowercased.contains(value.lowercased()) {
                tags.append(value)
            }
        }
        
        return tags
    }
    
    // MARK: - 默认值补齐（B 类）
    
    private func fillDefaults(_ slots: ExtractedSlots) -> (ExtractedSlots, [String]) {
        var filled = slots
        var assumptions: [String] = []
        
        let calendar = Calendar.current
        let today = Date()
        
        // 补齐日期（如果缺失）
        if filled.dateRange.value == nil && filled.durationDays.value == nil {
            // 默认：明天开始，1天
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
                filled.dateRange = SlotInfo(value: DateRange(startDate: tomorrow, endDate: tomorrow), confidence: 0.5)
                filled.durationDays = SlotInfo(value: 1, confidence: 0.5)
                assumptions.append("默认日期：明天（\(formatDate(tomorrow))）")
            }
        } else if filled.durationDays.value == nil && filled.dateRange.value != nil {
            // 有日期范围，计算天数
            let range = filled.dateRange.value!
            let days = calendar.dateComponents([.day], from: range.startDate, to: range.endDate).day ?? 1
            filled.durationDays = SlotInfo(value: max(1, days + 1), confidence: 0.5)
        }
        
        // 补齐偏好（如果缺失）
        if filled.pace.value == nil {
            filled.pace = SlotInfo(value: .moderate, confidence: 0.5)
            assumptions.append("默认节奏：中等")
        }
        
        if filled.walkingLevel.value == nil {
            filled.walkingLevel = SlotInfo(value: .normal, confidence: 0.5)
            assumptions.append("默认步行强度：正常")
        }
        
        if filled.transportPreference.value == nil {
            filled.transportPreference = SlotInfo(value: .publicTransport, confidence: 0.5)
            assumptions.append("默认交通：公共交通")
        }
        
        return (filled, assumptions)
    }
    
    // MARK: - 风险验证
    
    private func validateRisks(_ slots: ExtractedSlots) -> [String] {
        var risks: [String] = []
        
        if slots.destination.value == nil || slots.destination.confidence < 0.5 {
            risks.append("目的地不明确")
        }
        
        if slots.dateRange.value == nil && slots.durationDays.value == nil {
            risks.append("缺少日期或天数信息")
        }
        
        return risks
    }
    
    // MARK: - 辅助方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
