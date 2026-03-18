import Foundation

struct AvailabilityCoordinationFormState: Hashable {
    var participants: [ParsedParticipant]
    var startDate: Date
    var endDate: Date
    var durationMinutes: Int
    var coordinationMode: CoordinationMode
    var collectionMethod: AvailabilityCollectionMethod
    var note: String
    var timezoneIdentifier: String

    init(
        participants: [ParsedParticipant] = [ParsedParticipant(name: "我", role: .selfUser, isRequired: true)],
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        durationMinutes: Int = 60,
        coordinationMode: CoordinationMode = .strictIntersection,
        collectionMethod: AvailabilityCollectionMethod = .manualSelection,
        note: String = "",
        timezoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.participants = participants
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.coordinationMode = coordinationMode
        self.collectionMethod = collectionMethod
        self.note = note
        self.timezoneIdentifier = timezoneIdentifier
    }

    /// 以日曆日起訖涵蓋整日（避免同日開始結束變成 0 長度）
    var dateRange: DateInterval {
        let cal = Calendar.current
        let s = cal.startOfDay(for: min(startDate, endDate))
        let endDay = max(startDate, endDate)
        let e = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endDay) ?? endDay
        return DateInterval(start: s, end: e)
    }
}
