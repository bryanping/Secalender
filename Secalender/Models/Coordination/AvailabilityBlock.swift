import Foundation

enum AvailabilityPreference: String, Codable, CaseIterable, Hashable {
    case preferred
    case acceptable
    case unavailable

    var scoreWeight: Double {
        switch self {
        case .preferred:
            return 1.0
        case .acceptable:
            return 0.65
        case .unavailable:
            return 0.0
        }
    }
}

struct AvailabilityBlock: Identifiable, Codable, Hashable {
    var id: String
    var start: Date
    var end: Date
    var preference: AvailabilityPreference

    init(
        id: String = UUID().uuidString,
        start: Date,
        end: Date,
        preference: AvailabilityPreference = .preferred
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.preference = preference
    }

    var durationMinutes: Int {
        max(Int(end.timeIntervalSince(start) / 60), 0)
    }
}
