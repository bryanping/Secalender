//
//  InterestPreferenceSupplement.swift
//  Secalender
//
//  興趣偏好「補充主題」：與主畫面六類興趣同維度，並含休憩／景點／親子／其他（對齊充實行程表單周邊類型）。
//

import Foundation

/// 補充主題（可多選）；用於再向資料庫／AI 拉一批周邊推薦地點。
enum InterestPreferenceSupplementKind: String, CaseIterable, Identifiable, Hashable {
    case food
    case history
    case nature
    case shopping
    case nightlife
    case art
    case rest
    case scenic
    case family
    case other
    
    var id: String { rawValue }
    
    /// 與 `InterestTag` 對應的六類（rawValue 相同）
    var interestTag: InterestTag? {
        InterestTag(rawValue: rawValue)
    }
    
    /// 地點 id 前綴：`supp_<rawValue>_`
    var placeIdPrefix: String { "supp_\(rawValue)" }
    
    /// 載入中佇列 key（避免與主興趣 `food` 等衝突）
    var loadingQueryKey: String { "supp:\(rawValue)" }
    
    /// 給生成 prompt／自訂標籤串的簡稱（中文，與既有興趣文案一致）
    func promptLabelZh() -> String {
        if let t = interestTag {
            return TravelSpecialExperienceCatalog.promptInterestLabel(t)
        }
        switch self {
        case .rest: return "休憩"
        case .scenic: return "景點"
        case .family: return "親子"
        case .other: return "其他"
        default: return rawValue
        }
    }
    
    /// 由地點 id（`supp_<kind>_...`）還原補充主題
    static func kindFromPlaceId(_ id: String) -> InterestPreferenceSupplementKind? {
        guard id.hasPrefix("supp_") else { return nil }
        let rest = id.dropFirst("supp_".count)
        guard let idx = rest.firstIndex(of: "_") else { return nil }
        let head = String(rest[..<idx])
        return InterestPreferenceSupplementKind(rawValue: head)
    }
}
