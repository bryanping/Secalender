import Foundation

struct ParsedPlannerIntent: Hashable {
    var modelType: PlannerModelType
    var displayType: String
    var durationDays: Int?
    var durationHint: String?
    var location: String?
    var locationHint: String?
    var goal: String?
    var pace: String?
    var rawInput: String
    var taskDeadlineOffsetDays: Int?

    // 修改内容：多人協調相關欄位
    var participants: [ParsedParticipant]
    var coordinationMode: CoordinationMode?
    var meetingDurationMinutes: Int?
    var dateRange: DateInterval?
    var missingFields: [PlannerMissingField]
    var confidence: Double

    init(
        modelType: PlannerModelType,
        displayType: String,
        durationDays: Int? = nil,
        durationHint: String? = nil,
        location: String? = nil,
        locationHint: String? = nil,
        goal: String? = nil,
        pace: String? = nil,
        rawInput: String,
        taskDeadlineOffsetDays: Int? = nil,
        participants: [ParsedParticipant] = [],
        coordinationMode: CoordinationMode? = nil,
        meetingDurationMinutes: Int? = nil,
        dateRange: DateInterval? = nil,
        missingFields: [PlannerMissingField] = [],
        confidence: Double = 0.7
    ) {
        self.modelType = modelType
        self.displayType = displayType
        self.durationDays = durationDays
        self.durationHint = durationHint
        self.location = location
        self.locationHint = locationHint
        self.goal = goal
        self.pace = pace
        self.rawInput = rawInput
        self.taskDeadlineOffsetDays = taskDeadlineOffsetDays
        self.participants = participants
        self.coordinationMode = coordinationMode
        self.meetingDurationMinutes = meetingDurationMinutes
        self.dateRange = dateRange
        self.missingFields = missingFields
        self.confidence = confidence
    }
}
