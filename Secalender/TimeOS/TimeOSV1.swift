import Foundation
import SwiftUI

// MARK: - Models

enum TimeOSIntent: String, Codable {
    case createPlan
    case optimizePlan
    case reschedulePlan
    case breakDownGoal
    case recommendAction
}

enum TimeOSScenario: String, Codable {
    case singleDayTrip
    case multiDayTrip
    case taskBreakdown
    case deadlinePlanning
    case todayReschedule
}

enum TimeOSCapability: String, Codable {
    case itinerary
    case taskPlanning
    case deadlinePlanning
    case realtimeAdjustment
    case decisionSupport
}

enum MissingField: String, Codable, CaseIterable {
    case date
    case dateRange
    case durationDays
    case location
    case participants
    case deadline
    case availableTime
    case priority
}

struct PlanningConstraint: Codable, Identifiable {
    let id: String
    let type: ConstraintType
    let value: String

    init(id: String = UUID().uuidString, type: ConstraintType, value: String) {
        self.id = id
        self.type = type
        self.value = value
    }
}

enum ConstraintType: String, Codable {
    case fixedTime
    case deadline
    case availability
    case preference
}

struct PlanningPreferences: Codable {
    var pace: String?
    var budgetLevel: String?
    var focusMode: String?

    static let empty = PlanningPreferences(pace: nil, budgetLevel: nil, focusMode: nil)
}

struct CapabilityRoutingResult: Codable {
    let scenario: TimeOSScenario?
    let capabilities: [TimeOSCapability]
}

struct NormalizedPlanningInput: Codable {
    let requestId: String
    let rawText: String

    var primaryIntent: TimeOSIntent
    var scenario: TimeOSScenario?
    var capabilities: [TimeOSCapability]

    /// 自然语言解析出的任务/主题短语（可选，用于展示与标题兜底）
    var extractedGoalPhrase: String?

    var title: String
    var startDate: Date?
    var endDate: Date?
    var deadline: Date?
    var durationDays: Int?

    var locationName: String?
    var participantSummary: String?

    var constraints: [PlanningConstraint]
    var preferences: PlanningPreferences

    var missingFields: [MissingField]
    var completenessScore: Double
}

// MARK: - 展示用中文（不进入 Codable 业务核心时可由 View 使用）

enum TimeOSDisplayNames {
    static func scenario(_ s: TimeOSScenario?) -> String {
        guard let s else { return "未识别" }
        switch s {
        case .singleDayTrip: return "单日行程"
        case .multiDayTrip: return "多日行程"
        case .taskBreakdown: return "任务拆解"
        case .deadlinePlanning: return "截止倒排"
        case .todayReschedule: return "今日重排"
        }
    }

    static func intent(_ i: TimeOSIntent) -> String {
        switch i {
        case .createPlan: return "新建规划"
        case .optimizePlan: return "优化规划"
        case .reschedulePlan: return "调整/重排"
        case .breakDownGoal: return "任务/目标拆解"
        case .recommendAction: return "建议下一步"
        }
    }

    static func missingField(_ f: MissingField) -> String {
        switch f {
        case .date: return "日期"
        case .dateRange: return "起迄日期"
        case .durationDays: return "天数"
        case .location: return "地点"
        case .participants: return "同行/参与者"
        case .deadline: return "截止时间"
        case .availableTime: return "可用时间"
        case .priority: return "优先级"
        }
    }

    static func capabilitiesLine(_ caps: [TimeOSCapability]) -> String {
        caps.map {
            switch $0 {
            case .itinerary: return "行程草案"
            case .taskPlanning: return "任务规划"
            case .deadlinePlanning: return "截止倒排"
            case .realtimeAdjustment: return "实时调整"
            case .decisionSupport: return "决策辅助"
            }
        }.joined(separator: " · ")
    }
}

struct TimePlan: Codable, Identifiable {
    let id: String
    let title: String
    let scenario: TimeOSScenario?
    let summary: String
    let days: [TimePlanDay]
    let warnings: [String]
    let confidence: Double
}

struct TimePlanDay: Codable, Identifiable {
    let id: String
    let dateLabel: String
    let items: [TimePlanItem]
}

struct TimePlanItem: Codable, Identifiable {
    let id: String
    let title: String
    let startText: String?
    let endText: String?
    let durationMinutes: Int?
    let note: String?
}

// MARK: - Engine

enum IntentClassifier {
    static func classify(_ text: String) -> TimeOSIntent {
        let normalized = text.lowercased()

        if normalized.contains("重排")
            || normalized.contains("延误")
            || normalized.contains("延誤")
            || normalized.contains("調整")
            || normalized.contains("调整")
            || normalized.contains("來不及")
            || normalized.contains("来不及")
            || (normalized.contains("突然") && (normalized.contains("会议") || normalized.contains("會議"))) {
            return .reschedulePlan
        }

        if normalized.contains("完成")
            || normalized.contains("任務")
            || normalized.contains("任务")
            || normalized.contains("專案")
            || normalized.contains("专案")
            || normalized.contains("项目")
            || normalized.contains("拆解")
            || normalized.contains("proposal")
            || normalized.contains("上架")
            || normalized.contains("简报")
            || normalized.contains("簡報") {
            return .breakDownGoal
        }

        return .createPlan
    }
}

enum CapabilityRouter {
    static func route(text: String, intent: TimeOSIntent) -> CapabilityRoutingResult {
        let t = text.lowercased()

        func hasAny(_ list: [String]) -> Bool { list.contains(where: { t.contains($0.lowercased()) }) }

        let travelWords = ["旅行", "行程", "旅遊", "安排", "一日游", "一日遊", "出差", "去", "游", "出门", "出門", "亲子", "親子"]
        let taskWords = ["任务", "任務", "拆解", "计划", "計畫", "完成", "推进", "推進", "上架", "proposal", "简报", "簡報", "这周", "這週", "本周", "本週"]
        let deadlineWords = ["截止", "交付", "周五前", "週五前", "周五", "週五", "明天前", "兩天內", "两天内", "今天前", "before", "前要交", "前交"]
        let singleDayWords = ["一日", "一天", "明天", "今日", "周六", "週六", "周日", "週日", "周一", "週一", "周二", "週二", "周三", "週三", "周四", "週四"]
        let multiDayWords = ["三天", "四天", "五天", "六天", "七天", "幾天", "几天", "多日", "三日", "四日", "五日", "兩天", "两天"]
        /// 今日重排：需「重排语义」或（今日/下午/晚上）与延误/重排等组合，避免仅凭「今天」误判为行程
        let rescheduleStrong = ["重排", "延误", "延誤", "來不及", "来不及", "調整", "调整", "插入", "重新安排"]
        let rescheduleContext = ["今天", "下午", "晚上", "今早", "今晚"]

        var scenario: TimeOSScenario? = nil

        if intent == .reschedulePlan || hasAny(rescheduleStrong) || (hasAny(rescheduleContext) && hasAny(["延误", "延誤", "重排", "來不及", "来不及", "会议", "會議", "插入"])) {
            scenario = .todayReschedule
        } else if hasAny(deadlineWords) && (intent == .breakDownGoal || hasAny(taskWords)) {
            scenario = .deadlinePlanning
        } else if hasAny(multiDayWords) && hasAny(travelWords) {
            scenario = .multiDayTrip
        } else if hasAny(singleDayWords) && hasAny(travelWords) {
            scenario = .singleDayTrip
        } else if hasAny(taskWords) || intent == .breakDownGoal {
            scenario = .taskBreakdown
        }

        if scenario == nil {
            if hasAny(multiDayWords) { scenario = .multiDayTrip }
            else if hasAny(singleDayWords) { scenario = .singleDayTrip }
            else if hasAny(taskWords) { scenario = .taskBreakdown }
        }

        var capabilities: [TimeOSCapability] = [.decisionSupport]
        switch scenario {
        case .singleDayTrip, .multiDayTrip:
            capabilities = [.itinerary, .decisionSupport]
        case .taskBreakdown:
            capabilities = [.taskPlanning, .deadlinePlanning]
        case .deadlinePlanning:
            capabilities = [.deadlinePlanning, .taskPlanning]
        case .todayReschedule:
            capabilities = [.realtimeAdjustment, .decisionSupport]
        case .none:
            capabilities = [.decisionSupport]
        }

        return CapabilityRoutingResult(scenario: scenario, capabilities: capabilities)
    }
}

enum QuickEntryHandler {
    enum QuickEntryType: CaseIterable {
        case singleDay
        case multiDay
        case taskPlan
        case todayReschedule

        var title: String {
            switch self {
            case .singleDay: return "一日安排"
            case .multiDay: return "多日行程"
            case .taskPlan: return "任务计划"
            case .todayReschedule: return "今日重排"
            }
        }

        var scenario: TimeOSScenario {
            switch self {
            case .singleDay: return .singleDayTrip
            case .multiDay: return .multiDayTrip
            case .taskPlan: return .taskBreakdown
            case .todayReschedule: return .todayReschedule
            }
        }
    }

    static func buildInitial(type: QuickEntryType) -> NormalizedPlanningInput {
        let requestId = UUID().uuidString
        let rawText = type.title

        let scenario = type.scenario
        let capabilities: [TimeOSCapability]
        let missingFields: [MissingField]
        let title: String

        switch scenario {
        case .singleDayTrip:
            capabilities = [.itinerary, .decisionSupport]
            missingFields = [.date, .location]
            title = "一日安排"
        case .multiDayTrip:
            capabilities = [.itinerary, .decisionSupport]
            missingFields = [.durationDays, .location]
            title = "多日行程"
        case .taskBreakdown:
            capabilities = [.taskPlanning, .deadlinePlanning]
            missingFields = [.deadline]
            title = "任务计划"
        case .todayReschedule:
            capabilities = [.realtimeAdjustment, .decisionSupport]
            missingFields = [.availableTime]
            title = "今日重排"
        case .deadlinePlanning:
            capabilities = [.deadlinePlanning, .taskPlanning]
            missingFields = [.deadline]
            title = "截止倒排"
        }

        var npi = NormalizedPlanningInput(
            requestId: requestId,
            rawText: rawText,
            primaryIntent: .createPlan,
            scenario: scenario,
            capabilities: capabilities,
            extractedGoalPhrase: nil,
            title: title,
            startDate: nil,
            endDate: nil,
            deadline: nil,
            durationDays: nil,
            locationName: nil,
            participantSummary: nil,
            constraints: [],
            preferences: .empty,
            missingFields: missingFields,
            completenessScore: 0.3
        )

        let result = MissingFieldDetector.evaluate(npi)
        npi.missingFields = result.missingFields
        npi.completenessScore = result.completenessScore
        return npi
    }
}

enum MissingFieldDetector {
    struct Result {
        let missingFields: [MissingField]
        let completenessScore: Double
    }

    static func evaluate(_ npi: NormalizedPlanningInput) -> Result {
        guard let scenario = npi.scenario else {
            return Result(missingFields: [.priority], completenessScore: 0.0)
        }

        let required: [MissingField] = requiredFields(for: scenario)
        let hasAvailabilityConstraint = npi.constraints.contains { $0.type == .availability }

        let missing = required.filter { field in
            switch field {
            case .date:
                return npi.startDate == nil && npi.endDate == nil
            case .dateRange:
                return npi.startDate == nil || npi.endDate == nil
            case .durationDays:
                return (npi.durationDays ?? 0) <= 0 && (npi.startDate == nil || npi.endDate == nil)
            case .location:
                return (npi.locationName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            case .participants:
                return (npi.participantSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            case .deadline:
                if scenario == .taskBreakdown {
                    return npi.deadline == nil && !hasAvailabilityConstraint
                }
                return npi.deadline == nil
            case .availableTime:
                if scenario == .taskBreakdown {
                    return !hasAvailabilityConstraint && npi.deadline == nil
                }
                return npi.constraints.first(where: { $0.type == .availability }) == nil
            case .priority:
                return false
            }
        }

        let total = max(required.count, 1)
        let score = 1.0 - (Double(missing.count) / Double(total))
        return Result(missingFields: missing, completenessScore: max(0.0, min(1.0, score)))
    }

    private static func requiredFields(for scenario: TimeOSScenario) -> [MissingField] {
        switch scenario {
        case .singleDayTrip: return [.date, .location]
        case .multiDayTrip: return [.location, .durationDays]
        /// 截止或可用时间二选一（evaluate 中对两项做 OR）
        case .taskBreakdown: return [.deadline, .availableTime]
        case .deadlinePlanning: return [.deadline]
        case .todayReschedule: return [.availableTime]
        }
    }
}

enum NPIBuilder {
    static func buildFromNaturalLanguage(text: String) -> NormalizedPlanningInput {
        let intent = IntentClassifier.classify(text)
        var routed = CapabilityRouter.route(text: text, intent: intent)
        let goal = extractGoalPhrase(from: text)
        var scenario = routed.scenario

        /// 多日 + 明確天數 + 地點 → 優先多日行程（避免被任務詞誤判）
        if extractDurationDays(from: text) != nil, extractLocation(from: text) != nil, hasTravelFlavor(text) {
            scenario = .multiDayTrip
            routed = CapabilityRoutingResult(scenario: scenario, capabilities: [.itinerary, .decisionSupport])
        }

        var npi = NormalizedPlanningInput(
            requestId: UUID().uuidString,
            rawText: text,
            primaryIntent: intent,
            scenario: scenario,
            capabilities: routed.capabilities,
            extractedGoalPhrase: goal,
            title: resolvedTitle(scenario: scenario, goal: goal, fallbackText: text),
            startDate: nil,
            endDate: nil,
            deadline: extractDeadline(from: text),
            durationDays: extractDurationDays(from: text),
            locationName: extractLocation(from: text),
            participantSummary: nil,
            constraints: [],
            preferences: .empty,
            missingFields: [],
            completenessScore: 0.0
        )

        if npi.startDate == nil && npi.endDate == nil, let sc = npi.scenario {
            if sc == .singleDayTrip, containsAny(text, ["今天", "明天", "今日"]) {
                npi.startDate = Calendar.current.date(byAdding: .day, value: text.contains("明天") ? 1 : 0, to: Date())
            }
            if sc == .multiDayTrip, text.contains("下周") || text.contains("下週") {
                npi.startDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
            }
        }

        let result = MissingFieldDetector.evaluate(npi)
        npi.missingFields = result.missingFields
        npi.completenessScore = result.completenessScore
        return npi
    }

    private static func hasTravelFlavor(_ text: String) -> Bool {
        let t = text.lowercased()
        let keys = ["排", "旅行", "行程", "旅遊", "去", "游", "出差", "安排"]
        return keys.contains(where: { t.contains($0) })
    }

    private static func resolvedTitle(scenario: TimeOSScenario?, goal: String?, fallbackText: String) -> String {
        if let g = goal, !g.isEmpty {
            switch scenario {
            case .taskBreakdown, .deadlinePlanning:
                return g
            default:
                break
            }
        }
        return defaultTitle(for: scenario, text: fallbackText)
    }

    private static func extractGoalPhrase(from text: String) -> String? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let strips = ["幫我", "帮我", "請", "请", "想", "要", "幫忙", "帮忙"]
        for p in strips where s.hasPrefix(p) {
            s.removeFirst(p.count)
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let patterns = [
            "這週要完成", "这周要完成", "本週要完成", "本周要完成",
            "我要完成", "要完成", "完成一下", "拆一下"
        ]
        for p in patterns {
            if let r = s.range(of: p) {
                s.removeSubrange(r)
                break
            }
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count >= 2 { return String(s.prefix(40)) }
        return nil
    }

    static func applyFieldUpdate(_ npi: NormalizedPlanningInput, field: MissingField, value: Any?) -> NormalizedPlanningInput {
        var updated = npi
        switch field {
        case .date:
            updated.startDate = value as? Date
            updated.endDate = value as? Date
        case .dateRange:
            if let pair = value as? (Date?, Date?) {
                updated.startDate = pair.0
                updated.endDate = pair.1
            }
        case .durationDays:
            updated.durationDays = value as? Int
        case .location:
            updated.locationName = value as? String
        case .deadline:
            updated.deadline = value as? Date
        case .availableTime:
            if let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.constraints.removeAll(where: { $0.type == .availability })
                updated.constraints.append(PlanningConstraint(type: .availability, value: text))
            }
        case .participants:
            updated.participantSummary = value as? String
        case .priority:
            break
        }

        let result = MissingFieldDetector.evaluate(updated)
        updated.missingFields = result.missingFields
        updated.completenessScore = result.completenessScore
        return updated
    }

    private static func defaultTitle(for scenario: TimeOSScenario?, text: String) -> String {
        switch scenario {
        case .singleDayTrip: return "一日安排"
        case .multiDayTrip: return "多日行程"
        case .taskBreakdown: return "任务计划"
        case .deadlinePlanning: return "截止倒排"
        case .todayReschedule: return "今日重排"
        case .none:
            return text.isEmpty ? "时间规划" : text
        }
    }

    private static func containsAny(_ text: String, _ list: [String]) -> Bool {
        list.contains(where: { text.contains($0) })
    }

    private static func extractDurationDays(from text: String) -> Int? {
        let mapping: [(String, Int)] = [
            ("一天", 1), ("1天", 1),
            ("兩天", 2), ("两天", 2), ("2天", 2),
            ("三天", 3), ("3天", 3), ("三日", 3),
            ("四天", 4), ("4天", 4), ("四日", 4),
            ("五天", 5), ("5天", 5),
            ("六天", 6), ("6天", 6),
            ("七天", 7), ("7天", 7)
        ]
        for (k, v) in mapping where text.contains(k) { return v }
        return nil
    }

    private static func extractLocation(from text: String) -> String? {
        let candidates = [
            "东京", "東京", "大阪", "京都", "北海道", "福岡", "福冈",
            "台北", "臺北", "台中", "臺中", "高雄", "花蓮",
            "上海", "北京", "深圳", "香港", "新加坡", "曼谷", "首爾", "首尔"
        ]
        for c in candidates where text.contains(c) { return c }

        if let range = text.range(of: "去") {
            var suffix = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let idx = suffix.firstIndex(of: "天") { suffix = String(suffix[..<idx]) }
            suffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
            if suffix.count >= 2 { return String(suffix.prefix(12)) }
        }
        return nil
    }

    private static func extractDeadline(from text: String) -> Date? {
        if text.contains("周五") || text.contains("週五") {
            return nextWeekday(.friday)
        }
        if text.contains("明天") {
            return Calendar.current.date(byAdding: .day, value: 1, to: Date())
        }
        if text.contains("兩天內") || text.contains("两天内") {
            return Calendar.current.date(byAdding: .day, value: 2, to: Date())
        }
        return nil
    }

    private static func nextWeekday(_ weekday: Weekday) -> Date? {
        let cal = Calendar.current
        var comp = cal.dateComponents([.year, .month, .day, .weekday], from: Date())
        guard let todayW = comp.weekday else { return nil }
        let target = weekday.calendarValue
        let delta = (target - todayW + 7) % 7
        let add = delta == 0 ? 7 : delta
        return cal.date(byAdding: .day, value: add, to: Date())
    }

    private enum Weekday {
        case friday
        var calendarValue: Int { 6 } // Sunday=1 ... Friday=6
    }
}

enum TimeAllocationEngine {
    static func generatePlan(from npi: NormalizedPlanningInput) -> TimePlan {
        let id = UUID().uuidString
        let scenario = npi.scenario
        var warnings: [String] = []

        if !npi.missingFields.isEmpty {
            warnings.append("資訊尚未完整，草案為示意，可先補齊必要欄位再生成更準確版本。")
        }

        let title = npi.title
        let (days, summary) = buildDaysAndSummary(npi: npi)
        let confidence = max(0.35, min(0.92, npi.completenessScore * 0.9 + (npi.missingFields.isEmpty ? 0.08 : 0.0)))

        return TimePlan(
            id: id,
            title: title,
            scenario: scenario,
            summary: summary,
            days: days,
            warnings: warnings,
            confidence: confidence
        )
    }

    private static func buildDaysAndSummary(npi: NormalizedPlanningInput) -> ([TimePlanDay], String) {
        switch npi.scenario {
        case .singleDayTrip:
            let location = npi.locationName ?? "未指定地点"
            let summary = "为「\(location)」生成一日分段草案（上午/中午/下午/晚上）。"
            return ([segmentDay(label: dateLabel(from: npi.startDate), segments: ["上午：抵达与热身", "中午：用餐与休息", "下午：核心行程", "晚上：收尾与返程"])], summary)

        case .multiDayTrip:
            let d = npi.durationDays ?? max(2, suggestedDaysFromRange(npi))
            let location = npi.locationName ?? "未指定地点"
            let summary = "为「\(location)」生成 \(d) 天游玩草案，每天 3–4 段。"
            var days: [TimePlanDay] = []
            for i in 1...d {
                days.append(segmentDay(label: "Day \(i)", segments: ["上午：重点景点", "中午：用餐", "下午：扩展行程", "晚上：散步/夜景/休息"]))
            }
            return (days, summary)

        case .taskBreakdown:
            let summary = "将任务拆为：准备 / 核心执行 / 检查收尾，并附简单节奏建议。"
            let day = TimePlanDay(
                id: UUID().uuidString,
                dateLabel: "任务拆解",
                items: [
                    TimePlanItem(id: UUID().uuidString, title: "准备：明确产出、收集资料、列出子任务", startText: nil, endText: nil, durationMinutes: 45, note: nil),
                    TimePlanItem(id: UUID().uuidString, title: "核心执行：按优先级推进 2–3 个关键子任务", startText: nil, endText: nil, durationMinutes: 120, note: nil),
                    TimePlanItem(id: UUID().uuidString, title: "检查/收尾：自检、补缺、输出提交版本", startText: nil, endText: nil, durationMinutes: 60, note: nil)
                ]
            )
            return ([day], summary)

        case .deadlinePlanning:
            let dl = npi.deadline
            let label = dl.map { "截止：\(shortDate($0))" } ?? "截止倒排"
            let summary = "按截止时间倒排：今天/明天/截止前需要完成什么。"
            let day = TimePlanDay(
                id: UUID().uuidString,
                dateLabel: label,
                items: [
                    TimePlanItem(id: UUID().uuidString, title: "今天：确定范围与最小可交付版本（MVP）", startText: nil, endText: nil, durationMinutes: 60, note: nil),
                    TimePlanItem(id: UUID().uuidString, title: "明天：完成核心内容并产出可审阅稿", startText: nil, endText: nil, durationMinutes: 120, note: nil),
                    TimePlanItem(id: UUID().uuidString, title: "截止前：最终修订、格式检查、提交", startText: nil, endText: nil, durationMinutes: 60, note: nil)
                ]
            )
            return ([day], summary)

        case .todayReschedule:
            let availability = npi.constraints.first(where: { $0.type == .availability })?.value ?? "未提供可用时间"
            let summary = "基于剩余可用时间（\(availability)）给出：可执行/压缩/延后建议。"
            let day = TimePlanDay(
                id: UUID().uuidString,
                dateLabel: "今天",
                items: [
                    TimePlanItem(id: UUID().uuidString, title: "当前可执行项：先做 1 个最关键任务（25–45 分钟）", startText: nil, endText: nil, durationMinutes: 45, note: nil),
                    TimePlanItem(id: UUID().uuidString, title: "压缩项：把次要任务改为「只做必要部分」", startText: nil, endText: nil, durationMinutes: 30, note: nil),
                    TimePlanItem(id: UUID().uuidString, title: "延后项：明确延后到明天的时间段并设置提醒", startText: nil, endText: nil, durationMinutes: 10, note: nil)
                ]
            )
            return ([day], summary)

        case .none:
            let summary = "尚未识别场景，先给出通用草案。"
            let day = TimePlanDay(
                id: UUID().uuidString,
                dateLabel: "草案",
                items: [
                    TimePlanItem(id: UUID().uuidString, title: "补齐关键信息（时间/地点/截止/可用时间）", startText: nil, endText: nil, durationMinutes: nil, note: nil)
                ]
            )
            return ([day], summary)
        }
    }

    private static func segmentDay(label: String, segments: [String]) -> TimePlanDay {
        TimePlanDay(
            id: UUID().uuidString,
            dateLabel: label,
            items: segments.map { s in
                TimePlanItem(id: UUID().uuidString, title: s, startText: nil, endText: nil, durationMinutes: nil, note: nil)
            }
        )
    }

    private static func suggestedDaysFromRange(_ npi: NormalizedPlanningInput) -> Int {
        guard let s = npi.startDate, let e = npi.endDate else { return 3 }
        let days = Calendar.current.dateComponents([.day], from: s, to: e).day ?? 2
        return max(2, days + 1)
    }

    private static func dateLabel(from date: Date?) -> String {
        guard let date else { return "当天" }
        return shortDate(date)
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        return f.string(from: date)
    }
}

enum PlanDraftBuilder {
    struct DraftSection: Identifiable {
        let id: String
        let title: String
        let lines: [String]
    }

    static func buildSections(from plan: TimePlan) -> [DraftSection] {
        var sections: [DraftSection] = []
        for day in plan.days {
            sections.append(
                DraftSection(
                    id: day.id,
                    title: day.dateLabel,
                    lines: day.items.map { $0.title }
                )
            )
        }
        return sections
    }
}

// MARK: - ViewModel

@MainActor
final class TimeSecretaryViewModel: ObservableObject {
    enum EntryMode {
        case quick(TimeOSScenario)
        case naturalLanguage
    }

    @Published var entryMode: EntryMode?
    @Published var inputText: String = ""
    @Published var currentNPI: NormalizedPlanningInput?
    @Published var missingFields: [MissingField] = []
    @Published var generatedPlan: TimePlan?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func selectQuickScenario(_ scenario: TimeOSScenario) {
        entryMode = .quick(scenario)
        let type: QuickEntryHandler.QuickEntryType
        switch scenario {
        case .singleDayTrip: type = .singleDay
        case .multiDayTrip: type = .multiDay
        case .taskBreakdown: type = .taskPlan
        case .todayReschedule: type = .todayReschedule
        case .deadlinePlanning: type = .taskPlan
        }

        let npi = QuickEntryHandler.buildInitial(type: type)
        currentNPI = npi
        missingFields = npi.missingFields
        generatedPlan = nil
        errorMessage = nil
    }

    func processNaturalLanguage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "请先输入一句话。"
            return
        }
        entryMode = .naturalLanguage
        let npi = NPIBuilder.buildFromNaturalLanguage(text: text)
        currentNPI = npi
        missingFields = npi.missingFields
        generatedPlan = nil
        errorMessage = nil
    }

    func updateField(_ field: MissingField, value: Any?) {
        guard let npi = currentNPI else { return }
        let updated = NPIBuilder.applyFieldUpdate(npi, field: field, value: value)
        currentNPI = updated
        missingFields = updated.missingFields
        errorMessage = nil
    }

    func generatePlan() {
        guard let npi = currentNPI else {
            errorMessage = "请先选择快速入口或输入一句话。"
            return
        }
        if !npi.missingFields.isEmpty {
            errorMessage = "请先补齐必要信息后再生成草案。"
            return
        }
        isLoading = true
        errorMessage = nil
        generatedPlan = TimeAllocationEngine.generatePlan(from: npi)
        isLoading = false
    }
}

// MARK: - Views

struct QuickEntrySection: View {
    let onSelect: (TimeOSScenario) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速开始")
                .font(.headline)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                Button("一日安排") { onSelect(.singleDayTrip) }
                Button("多日行程") { onSelect(.multiDayTrip) }
                Button("任务计划") { onSelect(.taskBreakdown) }
                Button("今日重排") { onSelect(.todayReschedule) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct ParsedIntentCard: View {
    let npi: NormalizedPlanningInput
    let entryMode: TimeSecretaryViewModel.EntryMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(cardTitle)
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(TimeOSDisplayNames.intent(npi.primaryIntent), systemImage: "arrow.triangle.branch")
                Text("·")
                    .foregroundStyle(.tertiary)
                Label(TimeOSDisplayNames.scenario(npi.scenario), systemImage: "map")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !npi.capabilities.isEmpty {
                Text("能力：\(TimeOSDisplayNames.capabilitiesLine(npi.capabilities))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider().opacity(0.35)

            VStack(alignment: .leading, spacing: 6) {
                Text("标题：\(npi.title)")
                    .font(.subheadline)
                if let goal = npi.extractedGoalPhrase, !goal.isEmpty {
                    Text("识别主题：\(goal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !recognizedLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已识别")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ForEach(recognizedLines, id: \.self) { line in
                        Text("· \(line)")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }

            HStack(spacing: 12) {
                Text("尚缺：\(npi.missingFields.count) 项")
                Text(String(format: "完整度：%.0f%%", npi.completenessScore * 100))
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !npi.missingFields.isEmpty {
                Text("待补齐：\(missingSummary)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var recognizedLines: [String] {
        var lines: [String] = []
        if let d = npi.durationDays {
            lines.append("行程天数：\(d) 天")
        }
        if let loc = npi.locationName, !loc.isEmpty {
            lines.append("地点：\(loc)")
        }
        if let dl = npi.deadline {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            lines.append("截止：\(f.string(from: dl))")
        }
        if let s = npi.startDate {
            let f = DateFormatter()
            f.dateStyle = .medium
            lines.append("开始日：\(f.string(from: s))")
        }
        return lines
    }

    private var missingSummary: String {
        npi.missingFields.map { TimeOSDisplayNames.missingField($0) }.joined(separator: "、")
    }

    private var cardTitle: String {
        switch entryMode {
        case .quick(let scenario):
            return "你正在创建：\(quickName(for: scenario))"
        case .naturalLanguage:
            return "我理解你想做的是：\(TimeOSDisplayNames.scenario(npi.scenario))"
        case .none:
            return "当前规划"
        }
    }

    private func quickName(for scenario: TimeOSScenario) -> String {
        switch scenario {
        case .singleDayTrip: return "一日安排"
        case .multiDayTrip: return "多日行程"
        case .taskBreakdown: return "任务计划"
        case .deadlinePlanning: return "截止倒排"
        case .todayReschedule: return "今日重排"
        }
    }
}

struct DynamicClarificationForm: View {
    @ObservedObject var vm: TimeSecretaryViewModel

    @State private var tempDurationDays: String = ""
    @State private var tempLocation: String = ""
    @State private var tempParticipants: String = ""
    @State private var tempAvailableTime: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.missingFields.isEmpty {
                EmptyView()
            } else {
                Text("补充必要信息")
                    .font(.headline)
                if vm.currentNPI?.scenario == .taskBreakdown,
                   vm.missingFields.contains(.deadline),
                   vm.missingFields.contains(.availableTime) {
                    Text("任务计划：填写「截止时间」或「可用时间」其中一项即可继续。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(vm.missingFields, id: \.self) { field in
                    fieldRow(field)
                }
            }
        }
        .onAppear {
            syncTempFromNPI()
        }
        .onChange(of: vm.currentNPI?.requestId) { _, _ in
            syncTempFromNPI()
        }
    }

    private func syncTempFromNPI() {
        guard let npi = vm.currentNPI else { return }
        if let d = npi.durationDays {
            tempDurationDays = String(d)
        }
        tempLocation = npi.locationName ?? ""
        tempAvailableTime = npi.constraints.first(where: { $0.type == .availability })?.value ?? ""
        tempParticipants = npi.participantSummary ?? ""
    }

    @ViewBuilder
    private func fieldRow(_ field: MissingField) -> some View {
        switch field {
        case .date:
            DatePicker("日期", selection: Binding(get: {
                vm.currentNPI?.startDate ?? Date()
            }, set: { newValue in
                vm.updateField(.date, value: newValue)
            }), displayedComponents: [.date])

        case .dateRange:
            VStack(alignment: .leading, spacing: 8) {
                DatePicker("开始日期", selection: Binding(get: {
                    vm.currentNPI?.startDate ?? Date()
                }, set: { newValue in
                    let currentEnd = vm.currentNPI?.endDate
                    vm.updateField(.dateRange, value: (newValue, currentEnd))
                }), displayedComponents: [.date])
                DatePicker("结束日期", selection: Binding(get: {
                    vm.currentNPI?.endDate ?? Date()
                }, set: { newValue in
                    let currentStart = vm.currentNPI?.startDate
                    vm.updateField(.dateRange, value: (currentStart, newValue))
                }), displayedComponents: [.date])
            }

        case .durationDays:
            TextField("天数（例如：3）", text: $tempDurationDays)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .onChange(of: tempDurationDays) { _, newValue in
                    if let v = Int(newValue), v > 0 {
                        vm.updateField(.durationDays, value: v)
                    }
                }

        case .location:
            TextField("地点（例如：东京）", text: $tempLocation)
                .textFieldStyle(.roundedBorder)
                .onChange(of: tempLocation) { _, newValue in
                    vm.updateField(.location, value: newValue)
                }

        case .deadline:
            DatePicker("截止日期时间", selection: Binding(get: {
                vm.currentNPI?.deadline ?? Date()
            }, set: { newValue in
                vm.updateField(.deadline, value: newValue)
            }), displayedComponents: [.date, .hourAndMinute])

        case .availableTime:
            TextField("可用时间（例如：18:00-22:00）", text: $tempAvailableTime)
                .textFieldStyle(.roundedBorder)
                .onChange(of: tempAvailableTime) { _, newValue in
                    vm.updateField(.availableTime, value: newValue)
                }

        case .participants:
            TextField("同行/参与者（例如：我和两位同事）", text: $tempParticipants)
                .textFieldStyle(.roundedBorder)
                .onChange(of: tempParticipants) { _, newValue in
                    vm.updateField(.participants, value: newValue)
                }

        case .priority:
            EmptyView()
        }
    }
}

struct PlanDraftView: View {
    let plan: TimePlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(plan.summary)
                .foregroundStyle(.secondary)
            Text(String(format: "置信度：%.0f%%", plan.confidence * 100))
                .font(.caption)
                .foregroundStyle(.tertiary)

            if !plan.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("提醒")
                        .font(.headline)
                    ForEach(plan.warnings, id: \.self) { w in
                        Text("• \(w)")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ForEach(PlanDraftBuilder.buildSections(from: plan)) { sec in
                VStack(alignment: .leading, spacing: 6) {
                    Text(sec.title)
                        .font(.headline)
                    ForEach(sec.lines, id: \.self) { line in
                        Text("• \(line)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct TimeSecretaryView: View {
    @StateObject private var vm = TimeSecretaryViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                QuickEntrySection { scenario in
                    vm.selectQuickScenario(scenario)
                }

                naturalLanguageSection

                if let npi = vm.currentNPI {
                    ParsedIntentCard(npi: npi, entryMode: vm.entryMode)
                    DynamicClarificationForm(vm: vm)
                }

                generateButton

                if let plan = vm.generatedPlan {
                    Divider().padding(.vertical, 8)
                    PlanDraftView(plan: plan)
                }

                if let msg = vm.errorMessage {
                    Text(msg)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .padding(16)
        }
        .navigationTitle("Time OS")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time OS V1")
                .font(.title2)
                .fontWeight(.bold)
            Text("快速入口 + 自然语言，先补关键字段，再生成可编辑草案。")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    private var naturalLanguageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("你想安排什么？")
                .font(.headline)
            TextField("例如：帮我排三天东京 / 我这周要完成 proposal / 今天下午延误了，帮我重排", text: $vm.inputText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("解析") { vm.processNaturalLanguage() }
                    .buttonStyle(.bordered)
                Spacer()
            }
        }
    }

    private var generateButton: some View {
        Button {
            vm.generatePlan()
        } label: {
            HStack {
                Spacer()
                Text(vm.isLoading ? "生成中…" : "生成草案")
                Spacer()
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(vm.isLoading || (vm.currentNPI?.missingFields.isEmpty != true))
    }
}

