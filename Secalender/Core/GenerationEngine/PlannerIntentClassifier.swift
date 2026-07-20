//
//  PlannerIntentClassifier.swift
//  Secalender
//
//  修改内容：Step5 — 智能規劃意圖解析主路徑改 LLM 分類（多語言）
//  PlannerAutoRouter（中文關鍵詞）降為 fallback：AI 關閉、無網路、解析失敗時使用。
//  輸出與原路徑同型別 ParsedPlannerIntent，呼叫端無需分支。
//

import Foundation

final class PlannerIntentClassifier {
    static let shared = PlannerIntentClassifier()
    private init() {}

    /// 主入口：LLM 分類（任意語言）；失敗回退關鍵詞路由
    func parse(input: String) async -> ParsedPlannerIntent {
        let fallback = PlannerAutoRouter.resolveModel(input: input)
        guard AIConfig.shared.isOpenAIEnabled else { return fallback }
        do {
            let dto = try await classifyWithLLM(input)
            return merge(dto: dto, rawInput: input, fallback: fallback)
        } catch {
            print("⚠️ [PlannerIntentClassifier] LLM 分類失敗，回退關鍵詞路由: \(error.localizedDescription)")
            return fallback
        }
    }

    // MARK: - LLM 回應結構

    private struct IntentDTO: Codable {
        var modelType: String
        var durationDays: Int?
        var deadlineOffsetDays: Int?
        var location: String?
        var goal: String?
        var pace: String?
        var participants: [ParticipantDTO]?
        var coordinationMode: String?
        var meetingDurationMinutes: Int?
        var confidence: Double?
    }

    private struct ParticipantDTO: Codable {
        var name: String
        var isRequired: Bool?
    }

    // MARK: - 合併：LLM 值優先，缺項用 fallback 補

    private func merge(dto: IntentDTO, rawInput: String, fallback: ParsedPlannerIntent) -> ParsedPlannerIntent {
        let modelType = PlannerModelType(rawValue: dto.modelType) ?? fallback.modelType
        let participants: [ParsedParticipant] = (dto.participants ?? []).map {
            ParsedParticipant(name: $0.name, role: .friend, isRequired: $0.isRequired ?? true)
        }
        return ParsedPlannerIntent(
            modelType: modelType,
            displayType: modelType.displayTitle,
            durationDays: dto.durationDays ?? fallback.durationDays,
            durationHint: (dto.durationDays ?? fallback.durationDays) == nil ? fallback.durationHint : nil,
            location: dto.location ?? fallback.location,
            locationHint: (dto.location ?? fallback.location) == nil ? fallback.locationHint : nil,
            goal: dto.goal ?? fallback.goal,
            pace: dto.pace ?? fallback.pace,
            rawInput: rawInput,
            taskDeadlineOffsetDays: dto.deadlineOffsetDays ?? fallback.taskDeadlineOffsetDays,
            participants: participants.isEmpty ? fallback.participants : participants,
            coordinationMode: dto.coordinationMode.flatMap { CoordinationMode(rawValue: $0) } ?? fallback.coordinationMode,
            meetingDurationMinutes: dto.meetingDurationMinutes ?? fallback.meetingDurationMinutes,
            dateRange: fallback.dateRange,
            missingFields: fallback.missingFields,
            confidence: dto.confidence ?? 0.85
        )
    }

    // MARK: - LLM 呼叫（輕量、低溫、強制 JSON）

    private func classifyWithLLM(_ input: String) async throws -> IntentDTO {
        let prompt = """
        Classify the user's planning request (any language) into a scheduling intent. Output ONLY a JSON object, no markdown.

        modelType must be one of:
        - "multiPhase": trip/itinerary/outing planning (travel, day trips, food tours)
        - "floatingTask": tasks/work with a deadline, no fixed time (reports, study goals, chores)
        - "availabilityCoordination": coordinating a meeting time among multiple people
        - "recurring": recurring schedule (weekly lessons, monthly maintenance)
        - "aiOptimization": "arrange my day/week optimally" style requests
        - "availability": collecting the user's own free time slots
        - "matching": matching two parties (tutor & student, workout partners)

        Fields:
        {"modelType": "...", "durationDays": int or null, "deadlineOffsetDays": int or null (days from today to deadline, for floatingTask), "location": string or null (city/place, keep user's language), "goal": string or null (short summary, keep user's language), "pace": null, "participants": [{"name": "...", "isRequired": true}] or [], "coordinationMode": one of "strictIntersection"|"majorityVote"|"hostCentric"|"requiredOptionalMix"|"recurringBestFit" or null, "meetingDurationMinutes": int or null, "confidence": 0.0-1.0}

        User request: \(input)
        """

        // 修改内容：P0-2 — 改經 aiProxy，App 不再持有 API Key
        let content = try await AIProxyClient.shared.chat(
            model: "gpt-4o-mini",
            messages: [
                ["role": "system", "content": "You are an intent classifier. Output only valid JSON."],
                ["role": "user", "content": prompt]
            ],
            temperature: 0.1,
            maxTokens: 300,
            jsonMode: true,
            timeout: 20
        )
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let dtoData = cleaned.data(using: .utf8) else {
            throw NSError(domain: "PlannerIntentClassifier", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法解析 JSON"])
        }
        return try JSONDecoder().decode(IntentDTO.self, from: dtoData)
    }
}
