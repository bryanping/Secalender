import Foundation

enum CoordinationMode: String, Codable, CaseIterable, Hashable {
    case strictIntersection
    case majorityVote
    case hostCentric
    case requiredOptionalMix
    case recurringBestFit

    var displayTitle: String {
        switch self {
        case .strictIntersection:
            return "所有人都可"
        case .majorityVote:
            return "最多人可參加"
        case .hostCentric:
            return "以我為主"
        case .requiredOptionalMix:
            return "必要 + 可選"
        case .recurringBestFit:
            return "固定最佳時段"
        }
    }

    var detailDescription: String {
        switch self {
        case .strictIntersection:
            return "找出所有參與者都能參加的時間"
        case .majorityVote:
            return "找出最多人能參與的候選時段"
        case .hostCentric:
            return "優先配合發起人的時間"
        case .requiredOptionalMix:
            return "先滿足必要參與者，再增加可選參與者"
        case .recurringBestFit:
            return "找出每週或固定週期最穩定的時段"
        }
    }
}
