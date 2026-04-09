//
//  GenerationOrchestrator.swift
//  Secalender
//
//  生成總控：唯一對外入口。薄版 Parser/Classifier 內含於此，只呼叫 AITripGenerator 不重寫 prompt/parse。
//

import Foundation
import CoreLocation

enum GenerationOrchestratorError: LocalizedError {
    case missingDestination
    case missingDateInfo
    case themeRejected(String)
    case contextFailed(String)
    case generationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingDestination: return "請填寫目的地"
        case .missingDateInfo: return "請填寫日期範圍"
        case .themeRejected(let msg): return msg
        case .contextFailed(let msg): return msg
        case .generationFailed(let e): return e.localizedDescription
        }
    }
}

final class GenerationOrchestrator {
    static let shared = GenerationOrchestrator()
    private let themeResolver = ThemeResolver.shared
    private let contextProvider = ContextProvider.shared
    private let normalizer = GenerationNormalizer.shared
    private let conflictDetector = ConflictDetector.shared
    private init() {}

    /// 將目的地字串轉為座標（首段城際時間估算用）
    private func geocodeLocation(from address: String) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(address) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location)
            }
        }
    }

    private func isoCountryCode(for location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.isoCountryCode)
            }
        }
    }

    private func isoCountryCodeFromAddress(_ address: String) async -> String? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(address) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.isoCountryCode)
            }
        }
    }

    /// 門到門交通粗估（市內／城際鐵路／航空），優先「出發→住宿座標」，否則「出發→目的地」
    private func computeTransitEstimate(request: GenerateRequest, destination: String) async -> TransitEstimate? {
        guard let dep = request.departureLocation else { return nil }
        let toLoc: CLLocation
        if let c = request.accommodationCoordinate {
            toLoc = CLLocation(latitude: c.latitude, longitude: c.longitude)
        } else if let loc = await geocodeLocation(from: destination) {
            toLoc = loc
        } else {
            return nil
        }
        let originCC = await isoCountryCode(for: dep)
        let destCC: String?
        if request.accommodationCoordinate != nil {
            destCC = await isoCountryCode(for: toLoc)
        } else {
            destCC = await isoCountryCodeFromAddress(destination)
        }
        let international: Bool = {
            guard let a = originCC, let b = destCC else { return false }
            return a != b
        }()
        return TransitEstimateCalculator.estimate(from: dep, to: toLoc, isInternational: international)
    }

    /// 唯一入口：執行生成並回傳 GenerationResult
    func generate(request: GenerateRequest) async throws -> GenerationResult {
        let needsItinerarySlots = request.generateMode == .singleDay || request.generateMode == .multiDay
        if needsItinerarySlots {
            guard request.slots.destination.value != nil else {
                throw GenerationOrchestratorError.missingDestination
            }
            guard request.slots.dateRange.value != nil else {
                throw GenerationOrchestratorError.missingDateInfo
            }
        }

        let resolution = try await themeResolver.resolve(request: request)
        let context = try await contextProvider.fetchContext(for: request)

        // 任務拆解：本地 fallback 產生 task candidates，再排程與衝突檢測，統一回傳 GenerationResult
        if request.generateMode == .taskBreakdown {
            return try runTaskBreakdown(request: request, context: context)
        }

        let dateRange = request.slots.dateRange.value!
        let destination = request.slots.destination.value!
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: dateRange.startDate, to: dateRange.endDate).day ?? 1
        let numberOfDays = max(1, days + 1)

        let transitEst = await computeTransitEstimate(request: request, destination: destination)

        let aiPlan = try await AITripGenerator.shared.generateAIItinerary(
            destination: destination,
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
            durationDays: numberOfDays,
            interestTags: request.slots.interestTags,
            pace: request.slots.pace.value ?? .relaxed,
            walkingLevel: request.slots.walkingLevel.value,
            transportPreference: request.slots.transportPreference.value,
            selectedAttractions: request.selectedAttractionNames,
            customTags: request.customSurroundingTags,
            currentGPSLocation: request.departureLocation,
            accommodationAddress: request.accommodationAddress,
            accommodationType: request.accommodationAddress != nil ? "住宿地址" : nil,
            adults: request.adults,
            children: request.children,
            customAIInstructions: request.customInstructions,
            themeKey: request.themeKey,
            themePromptPrefix: resolution.promptPrefix,
            travelThemeId: request.travelThemeModuleId,
            departureDateTime: request.departureDateTime,
            transitEstimate: transitEst
        )

        let missingTagCoverage = AITripGenerator.validateCustomTagCoverage(plan: aiPlan, tags: request.customSurroundingTags)

        let conversionContext = AITripGenerator.PlanConversionContext(
            departureLocation: request.departureLocation,
            accommodationAddress: request.accommodationAddress,
            accommodationCoordinate: request.accommodationCoordinate,
            transportPreference: request.slots.transportPreference.value,
            departureDateTime: request.departureDateTime,
            transitEstimate: transitEst
        )
        var plan = try AITripGenerator.shared.convertToPlanResult(
            aiPlan,
            slots: request.slots,
            adults: request.adults,
            children: request.children,
            context: conversionContext
        )
        plan.assumptions = request.assumptions
        plan.riskFlags = request.riskFlags
        if !missingTagCoverage.isEmpty {
            plan.riskFlags.append("警示：以下自訂標籤在生成行程文字中未檢測到直接對應，請手動核實或重新生成：\(missingTagCoverage.joined(separator: "、"))")
        }
        // 修改内容：将主题与节奏信息写入结果，便于前端展示
        if let appliedThemeName = aiPlan.appliedThemeName {
            plan.riskFlags.append("已套用主题：\(appliedThemeName)")
        }
        if let intensity = aiPlan.appliedIntensity {
            plan.riskFlags.append("节奏强度：\(intensity.rawValue)")
        }

        var candidates = normalizer.normalize(plan: plan)
        let resultType = classifyResultType(candidates: candidates, plan: plan)
        if resultType == .untimedPlan || resultType == .taskOnly {
            let scheduled = GenerationSchedulerService.shared.schedule(
                untimedCandidates: candidates.filter { !$0.hasTime },
                rangeStart: context.rangeStart,
                rangeEnd: context.rangeEnd,
                existingItems: context.existingItems
            )
            let scheduledById = Dictionary(uniqueKeysWithValues: scheduled.map { ($0.id, $0) })
            candidates = candidates.map { c in
                if c.hasTime { return c }
                if let s = scheduledById[c.id] { return s }
                return c
            }
        }

        let conflicts = conflictDetector.detect(candidates: candidates, existingItems: context.existingItems)
        let requestId = UUID().uuidString
        return GenerationResult(
            resultType: resultType,
            plan: plan,
            candidates: candidates,
            conflicts: conflicts,
            assumptions: plan.assumptions,
            riskFlags: plan.riskFlags,
            requestId: requestId,
            themeKey: request.themeKey
        )
    }

    /// 薄版分類：依候選與 plan 決定 resultType
    private func classifyResultType(candidates: [TimeItemCandidate], plan: PlanResult) -> GenerationResultType {
        if plan.days.isEmpty || candidates.isEmpty { return .empty }
        let withTime = candidates.filter { $0.hasTime }
        if withTime.count == candidates.count { return .timedPlan }
        if candidates.allSatisfy({ $0.type == .task }) { return .taskOnly }
        if withTime.isEmpty { return .untimedPlan }
        return .partialSuccess
    }

    // MARK: - 任務拆解：本地 fallback 產生候選 → 排程 → 衝突檢測 → GenerationResult

    private func runTaskBreakdown(request: GenerateRequest, context: GenerationContext) throws -> GenerationResult {
        let untimedCandidates = buildTaskBreakdownCandidates(request: request)
        let scheduled = GenerationSchedulerService.shared.schedule(
            untimedCandidates: untimedCandidates,
            rangeStart: context.rangeStart,
            rangeEnd: context.rangeEnd,
            existingItems: context.existingItems
        )
        let conflicts = conflictDetector.detect(candidates: scheduled, existingItems: context.existingItems)
        let plan = PlanResult(days: [], assumptions: request.assumptions, riskFlags: request.riskFlags)
        return GenerationResult(
            resultType: .taskOnly,
            plan: plan,
            candidates: scheduled,
            conflicts: conflicts,
            assumptions: request.assumptions,
            riskFlags: request.riskFlags,
            requestId: UUID().uuidString,
            themeKey: request.themeKey
        )
    }

    /// 依標題/描述與 taskBreakdown 參數，用本地規則產出任務候選（無時間，供 scheduler 填入）
    private func buildTaskBreakdownCandidates(request: GenerateRequest) -> [TimeItemCandidate] {
        let title = request.title ?? ""
        let description = request.description ?? ""
        let params = request.taskBreakdown
        let availableHoursPerDay = params?.availableHoursPerDay ?? 4
        let complexity = params?.taskComplexity ?? "medium"
        let calendar = Calendar.current
        let rangeStart = request.startDate ?? request.slots.dateRange.value?.startDate ?? Date()
        let rangeEnd = request.endDate ?? request.slots.dateRange.value?.endDate ?? (params?.deadline ?? calendar.date(byAdding: .day, value: 7, to: rangeStart)!)
        let totalDays = max(1, calendar.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 1)
        let totalMinutes = Int(Double(totalDays) * availableHoursPerDay * 60)

        let stepTitles = subtaskTitlesFrom(title: title, description: description)
        let count = max(1, min(stepTitles.count, 12))
        let minutesPerTask = max(15, totalMinutes / count)

        var list: [TimeItemCandidate] = []
        for (index, stepTitle) in stepTitles.prefix(count).enumerated() {
            let duration = adjustedDuration(minutes: minutesPerTask, complexity: complexity, index: index, count: count)
            list.append(TimeItemCandidate(
                id: UUID().uuidString,
                title: stepTitle,
                notes: nil,
                startAt: nil,
                endAt: nil,
                durationMin: duration,
                type: .task,
                location: nil,
                dayIndex: 0,
                sourceBlockId: nil
            ))
        }
        return list
    }

    /// 從標題與描述拆成子任務標題（本地規則）
    private func subtaskTitlesFrom(title: String, description: String) -> [String] {
        var raw: [String] = []
        if !description.isEmpty {
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            raw = trimmed
                .components(separatedBy: CharacterSet.newlines)
                .map { line in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("-") || t.hasPrefix("*") || t.hasPrefix("•") {
                        return String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
                    }
                    return t
                }
                .filter { $0.count > 0 }
        }
        if raw.isEmpty, !title.isEmpty {
            raw = title
                .split(separator: "、")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 0 }
        }
        if raw.isEmpty {
            raw = ["準備與規劃", "執行主要工作", "檢視與收尾"]
        }
        return Array(raw.prefix(12))
    }

    /// 依複雜度與順序微調單任務時長（分鐘）
    private func adjustedDuration(minutes: Int, complexity: String, index: Int, count: Int) -> Int {
        let base = max(15, minutes)
        switch complexity {
        case "high":
            return min(480, base + 30)
        case "low":
            return max(15, base - 15)
        default:
            return base
        }
    }
}
