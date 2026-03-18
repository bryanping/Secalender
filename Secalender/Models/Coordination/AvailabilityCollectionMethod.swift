import Foundation

enum AvailabilityCollectionMethod: String, Codable, CaseIterable, Hashable {
    case manualSelection
    case invitationLink
    case quickPoll
    case directCalendarAccess

    var displayTitle: String {
        switch self {
        case .manualSelection:
            return "手動選時段"
        case .invitationLink:
            return "邀請連結"
        case .quickPoll:
            return "候選時段投票"
        case .directCalendarAccess:
            return "直接讀取日曆"
        }
    }
}
