import Foundation

enum AvailabilityResponseStatus: String, Codable, CaseIterable, Hashable {
    case pending
    case submitted
    case declined
}

struct AvailabilityResponse: Identifiable, Codable, Hashable {
    var id: String
    var participantId: String
    var timeBlocks: [AvailabilityBlock]
    var timezoneIdentifier: String
    var submittedAt: Date?
    var responseStatus: AvailabilityResponseStatus

    init(
        id: String = UUID().uuidString,
        participantId: String,
        timeBlocks: [AvailabilityBlock] = [],
        timezoneIdentifier: String = TimeZone.current.identifier,
        submittedAt: Date? = nil,
        responseStatus: AvailabilityResponseStatus = .pending
    ) {
        self.id = id
        self.participantId = participantId
        self.timeBlocks = timeBlocks
        self.timezoneIdentifier = timezoneIdentifier
        self.submittedAt = submittedAt
        self.responseStatus = responseStatus
    }
}
