import Foundation

enum PlannerMissingField: String, Codable, CaseIterable, Hashable {
    case participants
    case dateRange
    case duration
    case coordinationMode
    case requiredParticipants
    case timezone
    case recurrenceRule
    case location
    case destination
    case startDate
    case endDate
    case deadline
    case title
}
