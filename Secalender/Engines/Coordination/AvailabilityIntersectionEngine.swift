import Foundation

enum AvailabilityIntersectionEngine {

    // 修改内容：主入口
    static func generateCandidates(
        request: CoordinationRequest,
        responses: [AvailabilityResponse]
    ) -> CoordinationResult {
        let candidates: [CoordinatedTimeCandidate]

        switch request.coordinationMode {
        case .strictIntersection:
            candidates = strictIntersection(request: request, responses: responses)
        case .majorityVote:
            candidates = majorityVote(request: request, responses: responses)
        case .hostCentric:
            candidates = majorityVote(request: request, responses: responses)
        case .requiredOptionalMix:
            candidates = requiredOptionalMix(request: request, responses: responses)
        case .recurringBestFit:
            candidates = majorityVote(request: request, responses: responses) // 修改内容：MVP 占位
        }

        let sorted = candidates.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.start < rhs.start
            }
            return lhs.score > rhs.score
        }

        return CoordinationResult(
            requestId: request.id,
            rankedCandidates: sorted,
            bestCandidate: sorted.first
        )
    }

    // 修改内容：所有人時段交集
    static func strictIntersection(
        request: CoordinationRequest,
        responses: [AvailabilityResponse]
    ) -> [CoordinatedTimeCandidate] {
        strictIntersectionCandidates(request: request, responses: responses)
    }

    // 修改内容：最多人可參加（slot 掃描）
    static func majorityVote(
        request: CoordinationRequest,
        responses: [AvailabilityResponse]
    ) -> [CoordinatedTimeCandidate] {
        buildSlotBasedCandidates(
            request: request,
            responses: responses,
            requireAllRequiredParticipants: false
        )
    }

    // 修改内容：必要參與者齊全後最大化可選
    static func requiredOptionalMix(
        request: CoordinationRequest,
        responses: [AvailabilityResponse]
    ) -> [CoordinatedTimeCandidate] {
        buildSlotBasedCandidates(
            request: request,
            responses: responses,
            requireAllRequiredParticipants: true
        )
    }

    // MARK: - Strict Intersection

    private static func strictIntersectionCandidates(
        request: CoordinationRequest,
        responses: [AvailabilityResponse]
    ) -> [CoordinatedTimeCandidate] {
        guard !responses.isEmpty else { return [] }

        let requiredDuration = TimeInterval(request.requiredDurationMinutes * 60)
        let relevantResponses = responses.filter { $0.responseStatus == .submitted }

        guard !relevantResponses.isEmpty else { return [] }

        var currentIntervals: [DateInterval] = [request.targetDateRange]

        for response in relevantResponses {
            let preferredIntervals = response.timeBlocks
                .filter { $0.preference != .unavailable }
                .map { DateInterval(start: $0.start, end: $0.end) }

            currentIntervals = intersectIntervals(currentIntervals, preferredIntervals)

            if currentIntervals.isEmpty {
                return []
            }
        }

        let valid = currentIntervals.filter { $0.duration >= requiredDuration }

        return valid.map {
            CoordinatedTimeCandidate(
                start: $0.start,
                end: minDate($0.start.addingTimeInterval(requiredDuration), $0.end),
                score: 1.0,
                availableParticipantIds: relevantResponses.map(\.participantId),
                unavailableParticipantIds: [],
                preferredParticipantIds: relevantResponses.map(\.participantId)
            )
        }
    }

    // MARK: - Shared Slot Builder

    private static func buildSlotBasedCandidates(
        request: CoordinationRequest,
        responses: [AvailabilityResponse],
        requireAllRequiredParticipants: Bool
    ) -> [CoordinatedTimeCandidate] {
        let slotMinutes = max(min(request.requiredDurationMinutes, 60), 15)
        let slotDuration = TimeInterval(slotMinutes * 60)
        let requiredDuration = TimeInterval(request.requiredDurationMinutes * 60)

        let requiredParticipantIds = Set(
            request.participants
                .filter(\.isRequired)
                .map(\.id)
        )

        let submitted = responses.filter { $0.responseStatus == .submitted }
        guard !submitted.isEmpty else { return [] }

        var cursor = request.targetDateRange.start
        var result: [CoordinatedTimeCandidate] = []

        while cursor.addingTimeInterval(requiredDuration) <= request.targetDateRange.end {
            let candidateEnd = cursor.addingTimeInterval(requiredDuration)

            var availableIds: [String] = []
            var unavailableIds: [String] = []
            var preferredIds: [String] = []
            var score: Double = 0

            for response in submitted {
                let matchingBlocks = response.timeBlocks.filter {
                    $0.start <= cursor && $0.end >= candidateEnd && $0.preference != .unavailable
                }

                if let bestBlock = matchingBlocks.max(by: { $0.preference.scoreWeight < $1.preference.scoreWeight }) {
                    availableIds.append(response.participantId)
                    score += bestBlock.preference.scoreWeight
                    if bestBlock.preference == .preferred {
                        preferredIds.append(response.participantId)
                    }
                } else {
                    unavailableIds.append(response.participantId)
                }
            }

            if requireAllRequiredParticipants {
                let availableSet = Set(availableIds)
                let allRequiredAvailable = requiredParticipantIds.isSubset(of: availableSet)
                if !allRequiredAvailable {
                    cursor = cursor.addingTimeInterval(slotDuration)
                    continue
                }
            }

            if !availableIds.isEmpty {
                result.append(
                    CoordinatedTimeCandidate(
                        start: cursor,
                        end: candidateEnd,
                        score: score,
                        availableParticipantIds: availableIds,
                        unavailableParticipantIds: unavailableIds,
                        preferredParticipantIds: preferredIds
                    )
                )
            }

            cursor = cursor.addingTimeInterval(slotDuration)
        }

        return deduplicateCandidates(result)
    }

    // MARK: - Helpers

    private static func intersectIntervals(
        _ lhs: [DateInterval],
        _ rhs: [DateInterval]
    ) -> [DateInterval] {
        var results: [DateInterval] = []

        for left in lhs {
            for right in rhs {
                let start = maxDate(left.start, right.start)
                let end = minDate(left.end, right.end)
                if start < end {
                    results.append(DateInterval(start: start, end: end))
                }
            }
        }

        return mergeIntervals(results)
    }

    private static func mergeIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return [] }

        var merged: [DateInterval] = []

        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: maxDate(current.end, interval.end))
            } else {
                merged.append(current)
                current = interval
            }
        }

        merged.append(current)
        return merged
    }

    private static func deduplicateCandidates(_ candidates: [CoordinatedTimeCandidate]) -> [CoordinatedTimeCandidate] {
        var seen: Set<String> = []
        var result: [CoordinatedTimeCandidate] = []

        for candidate in candidates {
            let key = "\(candidate.start.timeIntervalSince1970)-\(candidate.end.timeIntervalSince1970)"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(candidate)
            }
        }

        return result
    }

    private static func minDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs < rhs ? lhs : rhs
    }

    private static func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }
}
