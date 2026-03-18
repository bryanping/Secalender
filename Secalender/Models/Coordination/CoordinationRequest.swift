import Foundation

struct CoordinationRequest: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var createdByUserId: String
    var participants: [ParsedParticipant]
    var coordinationMode: CoordinationMode
    var collectionMethod: AvailabilityCollectionMethod
    var targetDateRange: DateInterval
    var requiredDurationMinutes: Int
    var timezoneIdentifier: String
    var note: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        createdByUserId: String,
        participants: [ParsedParticipant],
        coordinationMode: CoordinationMode,
        collectionMethod: AvailabilityCollectionMethod,
        targetDateRange: DateInterval,
        requiredDurationMinutes: Int,
        timezoneIdentifier: String = TimeZone.current.identifier,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.createdByUserId = createdByUserId
        self.participants = participants
        self.coordinationMode = coordinationMode
        self.collectionMethod = collectionMethod
        self.targetDateRange = targetDateRange
        self.requiredDurationMinutes = requiredDurationMinutes
        self.timezoneIdentifier = timezoneIdentifier
        self.note = note
        self.createdAt = createdAt
    }
}
