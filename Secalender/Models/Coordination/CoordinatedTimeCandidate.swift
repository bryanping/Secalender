import Foundation

struct CoordinatedTimeCandidate: Identifiable, Codable, Hashable {
    var id: String
    var start: Date
    var end: Date
    var score: Double
    var availableParticipantIds: [String]
    var unavailableParticipantIds: [String]
    var preferredParticipantIds: [String]

    init(
        id: String = UUID().uuidString,
        start: Date,
        end: Date,
        score: Double,
        availableParticipantIds: [String],
        unavailableParticipantIds: [String],
        preferredParticipantIds: [String]
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.score = score
        self.availableParticipantIds = availableParticipantIds
        self.unavailableParticipantIds = unavailableParticipantIds
        self.preferredParticipantIds = preferredParticipantIds
    }

    var durationMinutes: Int {
        max(Int(end.timeIntervalSince(start) / 60), 0)
    }
}
