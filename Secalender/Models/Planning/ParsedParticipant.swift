import Foundation

enum ParticipantRole: String, Codable, CaseIterable, Hashable {
    case selfUser
    case friend
    case family
    case coworker
    case guest
}

struct ParsedParticipant: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var role: ParticipantRole
    var isRequired: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        role: ParticipantRole,
        isRequired: Bool = true
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.isRequired = isRequired
    }
}
