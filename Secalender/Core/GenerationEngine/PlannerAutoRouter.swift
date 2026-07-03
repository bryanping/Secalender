//
//  PlannerAutoRouter.swift
//  Secalender
//
//  意圖導向：自然語言 → 自動判斷 PlannerModelType + 簡易解析（時間/地點/目標）
//

import Foundation

enum PlannerAutoRouter {
    // 依字長排序，先比長詞（橫濱、京都）
    private static let knownCities: [String] = {
        let all = [
            "橫濱", "沖繩", "京都", "大阪", "東京", "台北", "台中", "台南", "高雄", "奈良",
            "首爾", "香港", "上海", "北京", "新北", "桃園", "新竹", "名古屋", "福岡", "深圳", "釜山"
        ]
        return all.sorted { $0.count > $1.count }
    }()

    // 修改内容：主入口，先判多人協調，再判任務，再判旅遊
    static func resolveModel(input: String) -> ParsedPlannerIntent {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = raw.lowercased()

        if containsCoordinationKeywords(raw) {
            return parseCoordinationIntent(from: raw)
        }

        if isTaskIntent(text: text, raw: raw) {
            let days = extractDays(from: text)
            let offset = taskDeadlineOffsetDays(text: text, raw: raw, parsedDays: days)
            return ParsedPlannerIntent(
                modelType: .floatingTask,
                displayType: "任務拆解",
                durationDays: days,
                durationHint: days == nil ? "截止日可於下方調整" : nil,
                location: nil,
                locationHint: nil,
                goal: raw.isEmpty ? nil : raw,
                pace: nil,
                rawInput: raw,
                taskDeadlineOffsetDays: offset,
                participants: [],
                coordinationMode: nil,
                meetingDurationMinutes: nil,
                dateRange: nil,
                missingFields: [],
                confidence: 0.76
            )
        }

        let hasTravel = text.contains("旅遊") || text.contains("行程") || text.contains("親子") || text.contains("一日遊") ||
            text.contains("自由行") || text.contains("美食") || text.contains("放鬆") ||
            knownCities.contains { text.contains($0) }
        let days = extractDays(from: text)
        let loc = extractLocation(from: raw)
        let locHint: String? = loc.isEmpty && hasTravel ? "可於下方選擇目的地" : nil

        if hasTravel || !loc.isEmpty {
            let explicitMulti = (days ?? 0) > 1 || text.contains("多天") || text.contains("幾天") ||
                text.contains("三天") || text.contains("兩天") || text.contains("四天") || text.contains("五天") ||
                text.contains("一週") || text.contains("週末") || text.contains("兩天一夜")
            let explicitSingle = text.contains("一日遊") || text.contains("一天") || text.contains("1天") ||
                text.contains("明日") || text.contains("明天") || (text.contains("一日") && !text.contains("兩天一夜"))
            let isMultiDay = explicitMulti && !explicitSingle
            let resolvedDays: Int? = {
                if let d = days, d > 0 { return d }
                if explicitSingle { return 1 }
                if text.contains("週末") { return 2 }
                if isMultiDay { return 3 }
                if !loc.isEmpty || text.contains("放鬆") || text.contains("美食") { return 1 }
                return nil
            }()
            let displayDays = resolvedDays ?? (isMultiDay ? 3 : 1)
            return ParsedPlannerIntent(
                modelType: .multiPhase,
                displayType: isMultiDay ? "多日旅遊行程" : "單日行程",
                durationDays: resolvedDays,
                durationHint: resolvedDays == nil ? "天數可於下方調整（預設依行程約 \(displayDays) 天）" : nil,
                location: loc.isEmpty ? nil : loc,
                locationHint: locHint,
                goal: raw.isEmpty ? nil : raw,
                pace: text.contains("緊湊") ? "packed" : "relaxed",
                rawInput: raw,
                taskDeadlineOffsetDays: nil,
                participants: [],
                coordinationMode: nil,
                meetingDurationMinutes: nil,
                dateRange: nil,
                missingFields: loc.isEmpty && hasTravel ? [.destination] : [],
                confidence: 0.74
            )
        }

        let fuzzyDays = extractDays(from: text) ?? (text.contains("這週") || text.contains("本周") ? 7 : nil)
        let loc2 = extractLocation(from: raw)
        return ParsedPlannerIntent(
            modelType: .multiPhase,
            displayType: "主題規劃",
            durationDays: fuzzyDays,
            durationHint: fuzzyDays == nil ? "時間與地點可於下方補齊" : nil,
            location: loc2.isEmpty ? nil : loc2,
            locationHint: loc2.isEmpty ? "地點可於下方補齊" : nil,
            goal: raw.isEmpty ? nil : raw,
            pace: nil,
            rawInput: raw,
            taskDeadlineOffsetDays: nil,
            participants: [],
            coordinationMode: nil,
            meetingDurationMinutes: nil,
            dateRange: nil,
            missingFields: [],
            confidence: 0.55
        )
    }

    // MARK: - 修改内容：多人協調意圖解析

    private static func parseCoordinationIntent(from input: String) -> ParsedPlannerIntent {
        let participants = extractParticipantsIfPossible(from: input)
        let coordinationMode = parseCoordinationMode(input)
        let duration = extractMeetingDuration(input)
        let dateRange = extractDateRangeHint(from: input)

        var missingFields: [PlannerMissingField] = []
        if participants.count < 2 {
            missingFields.append(.participants)
        }
        if dateRange == nil {
            missingFields.append(.dateRange)
        }
        if duration == nil {
            missingFields.append(.duration)
        }

        let loc = extractLocation(from: input)
        return ParsedPlannerIntent(
            modelType: .availabilityCoordination,
            displayType: "多人時間協調",
            durationDays: nil,
            durationHint: nil,
            location: loc.isEmpty ? nil : loc,
            locationHint: nil,
            goal: input,
            pace: nil,
            rawInput: input,
            taskDeadlineOffsetDays: nil,
            participants: participants,
            coordinationMode: coordinationMode,
            meetingDurationMinutes: duration,
            dateRange: dateRange,
            missingFields: missingFields,
            confidence: 0.82
        )
    }

    // MARK: - Keyword Detection

    static func containsCoordinationKeywords(_ input: String) -> Bool {
        let keywords = [
            "大家", "一起", "共同", "都有空", "找時間",
            "約時間", "可用時間", "開會", "聚餐", "揪團",
            "會議", "排會議", "哪天有空", "收集時間", "投票",
            "我們都有空", "找共同時間", "和朋友", "和家人", "和團隊"
        ]
        return keywords.contains { input.contains($0) }
    }

    private static func isTaskIntent(text: String, raw: String) -> Bool {
        if text.contains("完成") || text.contains("專案") || text.contains("任務") { return true }
        if text.contains("簡報") || text.contains("企劃書") || text.contains("企劃案") { return true }
        if text.contains("做完") || text.contains("撰寫") || text.contains("提交") { return true }
        if raw.contains("這週把") || raw.contains("这周把") { return true }
        if (text.contains("一週") || text.contains("這週") || text.contains("本周")) && (text.contains("完成") || text.contains("做完")) {
            return true
        }
        return false
    }

    private static func taskDeadlineOffsetDays(text: String, raw: String, parsedDays: Int?) -> Int {
        if let d = parsedDays, d > 0 { return min(d, 365) }
        if text.contains("這週") || text.contains("本周") {
            return daysUntilEndOfWeek(from: Date())
        }
        if text.contains("一週") || text.contains("一星期") || text.contains("一周") {
            return 7
        }
        return 7
    }

    private static func daysUntilEndOfWeek(from date: Date) -> Int {
        let cal = Calendar.current
        let wd = cal.component(.weekday, from: date)
        let daysUntilSunday = (8 - wd) % 7
        return max(1, daysUntilSunday == 0 ? 7 : daysUntilSunday)
    }

    static func parseCoordinationMode(_ input: String) -> CoordinationMode {
        if input.contains("大家都") || input.contains("所有人") {
            return .strictIntersection
        }
        if input.contains("最多人") || input.contains("多數") {
            return .majorityVote
        }
        if input.contains("固定") || input.contains("每週") || input.contains("每周") {
            return .recurringBestFit
        }
        if input.contains("以我為主") || input.contains("配合我") {
            return .hostCentric
        }
        return .requiredOptionalMix
    }

    static func extractMeetingDuration(_ input: String) -> Int? {
        if input.contains("15分鐘") { return 15 }
        if input.contains("30分鐘") || input.contains("半小時") { return 30 }
        if input.contains("45分鐘") { return 45 }
        if input.contains("1小時") || input.contains("一小時") { return 60 }
        if input.contains("90分鐘") { return 90 }
        if input.contains("2小時") || input.contains("兩小時") { return 120 }
        if input.contains("半天") { return 240 }
        return nil
    }

    static func extractDateRangeHint(from input: String) -> DateInterval? {
        let calendar = Calendar.current
        let now = Date()

        if input.contains("今天"),
           let start = calendar.dateInterval(of: .day, for: now)?.start,
           let end = calendar.date(byAdding: .day, value: 1, to: start) {
            return DateInterval(start: start, end: end)
        }

        if input.contains("明天"),
           let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           let start = calendar.dateInterval(of: .day, for: tomorrow)?.start,
           let end = calendar.date(byAdding: .day, value: 1, to: start) {
            return DateInterval(start: start, end: end)
        }

        if input.contains("下週") || input.contains("下周") {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now),
                  let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekInterval.start),
                  let nextWeekEnd = calendar.date(byAdding: .day, value: 7, to: nextWeekStart) else {
                return nil
            }
            return DateInterval(start: nextWeekStart, end: nextWeekEnd)
        }

        if input.contains("這週") || input.contains("这周") || input.contains("本週") || input.contains("本周") {
            return calendar.dateInterval(of: .weekOfYear, for: now)
        }

        if input.contains("週末") || input.contains("周末") {
            guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
            guard let saturday = calendar.date(byAdding: .day, value: 5, to: currentWeek.start),
                  let monday = calendar.date(byAdding: .day, value: 7, to: currentWeek.start) else {
                return nil
            }
            return DateInterval(start: saturday, end: monday)
        }

        return nil
    }

    static func extractParticipantsIfPossible(from input: String) -> [ParsedParticipant] {
        var participants: [ParsedParticipant] = [
            ParsedParticipant(name: "我", role: .selfUser, isRequired: true)
        ]

        if input.contains("朋友") {
            participants.append(ParsedParticipant(name: "朋友", role: .friend, isRequired: true))
        }
        if input.contains("家人") || input.contains("全家") {
            participants.append(ParsedParticipant(name: "家人", role: .family, isRequired: true))
        }
        if input.contains("團隊") || input.contains("PM") || input.contains("設計") || input.contains("工程") {
            if input.contains("PM") {
                participants.append(ParsedParticipant(name: "PM", role: .coworker, isRequired: true))
            }
            if input.contains("設計") {
                participants.append(ParsedParticipant(name: "設計", role: .coworker, isRequired: true))
            }
            if input.contains("工程") {
                participants.append(ParsedParticipant(name: "工程", role: .coworker, isRequired: true))
            }
            if input.contains("團隊"), participants.count == 1 {
                participants.append(ParsedParticipant(name: "團隊成員", role: .coworker, isRequired: true))
            }
        }

        return participants
    }

    private static func extractDays(from text: String) -> Int? {
        if text.contains("兩天一夜") || text.contains("二天一夜") || text.contains("兩日一夜") { return 2 }
        if text.contains("三天兩夜") { return 3 }

        let chineseDayMap: [(String, Int)] = [
            ("十天", 10), ("九天", 9), ("八天", 8), ("七天", 7), ("六天", 6),
            ("五天", 5), ("四天", 4), ("三天", 3), ("兩天", 2), ("二天", 2), ("一天", 1)
        ]
        for (s, n) in chineseDayMap {
            if text.contains(s) { return n }
        }
        if text.contains("一週") || text.contains("一星期") || text.contains("一周") { return 7 }
        if text.contains("週末") { return 2 }
        if text.contains("一日遊") || (text.contains("一日") && text.contains("遊")) { return 1 }

        if let regex = try? NSRegularExpression(pattern: "(\\d+)\\s*天"),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text),
           let n = Int(String(text[range])), n > 0 { return n }

        return nil
    }

    private static func extractLocation(from raw: String) -> String {
        let text = raw
        var hits: [(offset: Int, city: String)] = []
        for city in knownCities {
            var start = text.startIndex
            while let r = text.range(of: city, range: start..<text.endIndex) {
                let off = text.distance(from: text.startIndex, to: r.lowerBound)
                hits.append((off, city))
                start = r.upperBound
            }
        }
        hits.sort { $0.offset < $1.offset }
        guard !hits.isEmpty else { return "" }

        if let quRange = text.range(of: "去") {
            let quEnd = text.distance(from: text.startIndex, to: quRange.upperBound)
            if let after = hits.first(where: { $0.offset >= quEnd }) {
                return after.city
            }
        }
        return hits[0].city
    }
}
