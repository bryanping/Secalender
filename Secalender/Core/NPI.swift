//
//  NPI.swift
//  Secalender
//
//  Normalized Planning Input：主題表單答案 → 標準輸入的統一映射層
//  禁止直接將原始表單答案拼接到 prompt，必須經 NPI 轉換
//

import Foundation

// MARK: - Plan Type
enum NPIPlanType: String, Codable, CaseIterable {
    case itinerary = "itinerary"       // 旅行/行程
    case task_plan = "task_plan"        // 成長/任務
    case collaboration = "collaboration" // 協作/會議
    case life_admin = "life_admin"      // 生活管理
}

// MARK: - 標準列舉值（UI 可顯示中文，NPI 存英文）
enum NPIPace: String, Codable { case relaxed, balanced, packed }
enum NPIBudgetLevel: String, Codable { case low, medium, high }

// MARK: - 欄位白名單（僅允許的 id 進入 NPI，其餘丟 constraints_text）
enum NPIFieldWhitelist {
    static let allowedIds: Set<String> = [
        "plan_start_date", "start_date", "end_date",
        "duration_days", "duration_weeks", "plan_duration_days", "plan_duration_weeks",
        "goal", "plan_goal",
        "pace", "budget_level",
        "must_do", "avoid", "constraints_text",
        "travel_destination", "travel_areas", "travel_transport_preference",
        "travel_food_preference", "travel_kids",
        "learn_subjects", "learn_daily_minutes", "learn_sessions_per_week", "learn_level",
        "fit_goal", "fit_sport_type", "fit_sessions_per_week", "fit_session_minutes",
        "meet_participants", "meet_location", "meet_online", "meet_agenda_items", "meet_duration_minutes",
        "home_tasks_scope", "home_rooms", "home_frequency",
        "move_from", "move_to", "move_items_scope",
        "destination", "sessions_per_week", "daily_time_budget_minutes",
        "participants", "time_windows"
    ]
    
    static func isAllowed(_ id: String) -> Bool {
        allowedIds.contains(id) || id.hasPrefix("plan_") || id.hasPrefix("travel_") ||
        id.hasPrefix("learn_") || id.hasPrefix("fit_") || id.hasPrefix("meet_") || id.hasPrefix("home_")
    }
}

// MARK: - NPI 標準輸入
struct NormalizedPlanningInput: Codable {
    var plan_type: NPIPlanType
    var start_date: String          // YYYY-MM-DD
    var end_date: String           // YYYY-MM-DD
    var timezone: String
    var goal: String
    
    var duration_days: Int?
    var duration_weeks: Int?
    var pace: String?
    var budget_level: String?
    var must_do: [String]?
    var avoid: [String]?
    var participants: [[String: String]]?
    var destination: String?
    var travel_areas: [String]?
    var transport_preference: String?
    var daily_time_budget_minutes: Int?
    var sessions_per_week: Int?
    var time_windows: [String]?
    var constraints_text: String?
    
    var extra: [String: String]?   // 其他白名單欄位
}

// MARK: - 欄位衝突優先級（高優先級覆蓋低）
// 1. 表單答案（用戶填寫）
// 2. 主題預設（theme 級）
// 3. 系統預設
enum NPIConflictPriority {
    static let fieldOrder: [String] = [
        "start_date", "end_date", "goal", "plan_type",
        "duration_days", "duration_weeks", "pace", "budget_level",
        "destination", "must_do", "avoid", "participants",
        "daily_time_budget_minutes", "sessions_per_week"
    ]
}

// MARK: - Generation Log
struct NPIGenerationLog: Codable {
    let timestamp: Date
    let themeKey: String
    let templateVersion: Int
    let mappingVersion: String
    let npi: NormalizedPlanningInput
    let rawFormAnswersCount: Int
    let validationPassed: Bool
    let validationErrors: [String]?
}

// MARK: - NPI Mapper
enum NPIMapper {
    static let mappingVersion = "npi.map.v1"
    static let defaultTimezone = "Asia/Taipei"
    
    /// ThemeFormAnswer → NPI（禁止直接拼接原始表單到 prompt）
    static func mapToNPI(
        formAnswers: [String: String],
        formQuestions: [ThemeFormQuestion],
        themeTitle: String,
        themeKey: String,
        planType: NPIPlanType = .itinerary,
        fixedStartDate: Date?,
        fixedDurationDays: Int?
    ) -> NormalizedPlanningInput {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // 1. 預設值策略
        var npi = defaultNPI(planType: planType, themeTitle: themeTitle)
        
        // 2. 時間推算（優先級：start+end > start+duration_days > start+duration_weeks）
        let startDate: Date
        if let fixed = fixedStartDate {
            startDate = fixed
        } else if let s = formAnswers["plan_start_date"] ?? formAnswers["start_date"],
                  let d = ISO8601DateFormatter().date(from: s) ?? dateFormatter.date(from: s) {
            startDate = d
        } else {
            startDate = Date()
        }
        
        let endDate: Date
        if let s = formAnswers["end_date"], let d = dateFormatter.date(from: s) {
            endDate = d
        } else if let days = fixedDurationDays ?? (formAnswers["duration_days"] ?? formAnswers["plan_duration_days"]).flatMap({ Int($0) }), days > 0 {
            endDate = Calendar.current.date(byAdding: .day, value: days - 1, to: startDate) ?? startDate
        } else if let weeks = (formAnswers["duration_weeks"] ?? formAnswers["plan_duration_weeks"]).flatMap({ Int($0) }), weeks > 0 {
            endDate = Calendar.current.date(byAdding: .day, value: weeks * 7 - 1, to: startDate) ?? startDate
        } else {
            endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        }
        
        npi.start_date = dateFormatter.string(from: startDate)
        npi.end_date = dateFormatter.string(from: endDate)
        
        if let d = (formAnswers["duration_days"] ?? formAnswers["plan_duration_days"]).flatMap({ Int($0) }) {
            npi.duration_days = d
        }
        if let w = (formAnswers["duration_weeks"] ?? formAnswers["plan_duration_weeks"]).flatMap({ Int($0) }) {
            npi.duration_weeks = w
        }
        
        // 3. 依 type 映射各欄位
        for q in formQuestions {
            guard let raw = formAnswers[q.id], !raw.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            guard NPIFieldWhitelist.isAllowed(q.id) else { continue }
            
            switch q.type {
            case .date:
                if ["plan_start_date", "start_date"].contains(q.id) {
                    if let d = ISO8601DateFormatter().date(from: raw) ?? dateFormatter.date(from: raw) {
                        npi.start_date = dateFormatter.string(from: d)
                    }
                } else if q.id == "end_date" {
                    if let d = dateFormatter.date(from: raw) {
                        npi.end_date = dateFormatter.string(from: d)
                    }
                }
            case .number:
                guard let v = Int(raw), v > 0 else { break }
                switch q.id {
                case "duration_days", "plan_duration_days": npi.duration_days = v
                case "duration_weeks", "plan_duration_weeks": npi.duration_weeks = v
                case "sessions_per_week", "fit_sessions_per_week", "learn_sessions_per_week": npi.sessions_per_week = v
                case "daily_time_budget_minutes", "learn_daily_minutes", "fit_session_minutes": npi.daily_time_budget_minutes = v
                case "meet_duration_minutes": break // 可擴展
                default: break
                }
            case .select:
                let enumVal = mapSelectToEnum(fieldId: q.id, value: raw)
                switch q.id {
                case "pace": npi.pace = enumVal ?? raw
                case "budget_level": npi.budget_level = enumVal ?? raw
                case "travel_transport_preference", "transport_preference": npi.transport_preference = raw
                case "learn_level": break
                default: break
                }
            case .multiSelect:
                let arr = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                switch q.id {
                case "must_do", "learn_subjects", "fit_sport_type": npi.must_do = arr
                case "avoid": npi.avoid = arr
                case "travel_areas", "travel_destination": npi.travel_areas = arr; if let first = arr.first { npi.destination = first }
                default: break
                }
            case .text:
                if ["goal", "plan_goal"].contains(q.id) {
                    npi.goal = raw
                } else if ["must_do", "meet_agenda_items"].contains(q.id) {
                    npi.must_do = raw.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                } else if q.id == "constraints_text" {
                    npi.constraints_text = raw
                } else if ["travel_destination", "destination"].contains(q.id) {
                    npi.destination = raw
                } else {
                    if npi.constraints_text != nil {
                        npi.constraints_text! += "\n\(q.id): \(raw)"
                    } else {
                        npi.constraints_text = "\(q.id): \(raw)"
                    }
                }
            }
        }
        
        // 4. goal 兜底
        if npi.goal.isEmpty {
            npi.goal = themeTitle
        }
        
        return npi
    }
    
    private static func defaultNPI(planType: NPIPlanType, themeTitle: String) -> NormalizedPlanningInput {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: today) ?? today
        return NormalizedPlanningInput(
            plan_type: planType,
            start_date: formatter.string(from: today),
            end_date: formatter.string(from: end),
            timezone: defaultTimezone,
            goal: themeTitle,
            duration_days: 7,
            duration_weeks: nil,
            pace: "balanced",
            budget_level: "medium",
            must_do: nil,
            avoid: nil,
            participants: nil,
            destination: nil,
            travel_areas: nil,
            transport_preference: nil,
            daily_time_budget_minutes: nil,
            sessions_per_week: nil,
            time_windows: nil,
            constraints_text: nil,
            extra: nil
        )
    }
    
    private static func mapSelectToEnum(fieldId: String, value: String) -> String? {
        let lower = value.lowercased()
        if fieldId == "pace" {
            if lower.contains("放鬆") || lower.contains("relaxed") { return "relaxed" }
            if lower.contains("緊湊") || lower.contains("packed") { return "packed" }
            return "balanced"
        }
        if fieldId == "budget_level" {
            if lower.contains("低") || lower.contains("low") { return "low" }
            if lower.contains("高") || lower.contains("high") { return "high" }
            return "medium"
        }
        return nil
    }
    
    /// 校驗 NPI，回傳錯誤列表
    static func validateNPI(_ npi: NormalizedPlanningInput) -> [String] {
        var errors: [String] = []
        
        if npi.goal.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("goal 為必填")
        }
        
        if npi.start_date.isEmpty {
            errors.append("start_date 為必填")
        }
        
        if npi.end_date.isEmpty {
            errors.append("end_date 為必填")
        }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if let sd = df.date(from: npi.start_date), let ed = df.date(from: npi.end_date), ed < sd {
            errors.append("end_date 不可早於 start_date")
        }
        
        switch npi.plan_type {
        case .itinerary:
            // destination 可為空時使用系統預設（如用戶所在地）
            break
        case .task_plan:
            if npi.daily_time_budget_minutes == nil && npi.sessions_per_week == nil {
                errors.append("task_plan 需填寫 daily_time_budget_minutes 或 sessions_per_week")
            }
        case .collaboration:
            if npi.participants == nil || (npi.participants?.isEmpty ?? true) {
                errors.append("collaboration 類型需填寫 participants")
            }
        case .life_admin:
            if (npi.constraints_text?.isEmpty ?? true) && npi.goal == npi.start_date {
                errors.append("life_admin 需填寫 tasks_scope 或 goal")
            }
        }
        
        return errors
    }
    
    /// 建立 generation_log
    static func buildGenerationLog(
        themeKey: String,
        npi: NormalizedPlanningInput,
        rawFormAnswersCount: Int,
        validationErrors: [String]
    ) -> NPIGenerationLog {
        NPIGenerationLog(
            timestamp: Date(),
            themeKey: themeKey,
            templateVersion: 1,
            mappingVersion: mappingVersion,
            npi: npi,
            rawFormAnswersCount: rawFormAnswersCount,
            validationPassed: validationErrors.isEmpty,
            validationErrors: validationErrors.isEmpty ? nil : validationErrors
        )
    }
    
    /// 將 NPI 轉為 AI 指令用的 JSON 字串（禁止傳原始 formAnswers）
    static func npiToPromptJSON(_ npi: NormalizedPlanningInput) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if let data = try? encoder.encode(npi), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
