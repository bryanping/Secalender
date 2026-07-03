//
//  TravelSpecialExperienceCatalog.swift
//  Secalender
//
//  旅遊規劃共用：興趣標籤文案、OpenAI 地點建議 prompt、已選真實地點展平至生成參數。
//

import Foundation

enum TravelSpecialExperienceCatalog {
    
    /// 寫入 AI prompt 用的興趣簡稱（不依賴 MainActor 本地化）
    static func promptInterestLabel(_ interest: InterestTag) -> String {
        switch interest {
        case .food: return "美食"
        case .history: return "歷史文化"
        case .nature: return "自然"
        case .shopping: return "購物"
        case .nightlife: return "夜生活"
        case .art: return "藝術"
        }
    }
    
    /// 興趣維度說明（給地點建議模型）
    static func interestFocusDescription(_ interest: InterestTag) -> String {
        switch interest {
        case .food:
            return "在地美食與餐飲：具體餐廳、小吃名店、夜市、咖啡或甜點名店（需為真實店名或場域名稱）"
        case .history:
            return "歷史文化：古蹟、博物館、紀念建築、歷史街區或老街（需為真實地點名稱）"
        case .nature:
            return "自然與戶外：公園、步道、觀景台、海濱或山景等具體地點"
        case .shopping:
            return "購物：商圈、市集、百貨、選物店或伴手禮名店等具體地點"
        case .nightlife:
            return "夜生活：夜景點、酒吧、夜間市集、音樂或表演場館等具體地點"
        case .art:
            return "藝文：美術館、展覽空間、劇場、文創園區或藝文街區等具體地點"
        }
    }
    
    /// 補充主題（休憩／景點／親子／其他）專用提示詞
    static func openAIPromptForSupplementKind(
        cityName: String,
        countryLine: String,
        kind: InterestPreferenceSupplementKind,
        otherHint: String?
    ) -> String {
        let focus: String
        switch kind {
        case .food, .history, .nature, .shopping, .nightlife, .art:
            focus = interestFocusDescription(kind.interestTag!)
        case .rest:
            focus = "休憩放鬆：咖啡廳、茶館、綠地、可久坐的公園廣場或百貨內可歇腳處等**具體場所名稱**"
        case .scenic:
            focus = "觀景與必訪景點：知名觀景台、河濱海濱步道、經典地標外景、拍照點等**具體地點名稱**"
        case .family:
            focus = "親子友善：動物園、水族館、兒童博物館、遊樂設施、親子餐廳等**具體地點名稱**"
        case .other:
            let hint = otherHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            focus = hint.isEmpty
                ? "符合旅客需求之真實地點"
                : "使用者補充說明：\(hint)。請依此搜尋**真實存在**且可造訪的具體地點名稱"
        }
        return """
        請列出\(cityName)\(countryLine) **真實存在**、旅客可實際造訪的具體地點名稱。
        主題重點：\(focus)
        規則：
        - 必須使用當地通用、可搜尋到的真實名稱；禁止虛構、禁止只回類別詞（例如不要只回「知名夜市」而要有具體名稱）。
        - 每個名稱應盡量對應單一 POI／場館／街區（必要時可用當地慣用簡稱）。
        - 輸出 4 到 8 個名稱，**僅**輸出 JSON 字串陣列，例如：["地點1","地點2"]
        """
    }
    
    /// 呼叫 OpenAI 取得「該興趣」真實地點名稱列表的提示詞
    static func openAIPromptForInterestPlaces(cityName: String, countryLine: String, interest: InterestTag) -> String {
        let focus = interestFocusDescription(interest)
        return """
        請列出\(cityName)\(countryLine) **真實存在**、旅客可實際造訪的具體地點名稱。
        主題重點：\(focus)
        規則：
        - 必須使用當地通用、可搜尋到的真實名稱；禁止虛構、禁止只回類別詞（例如不要只回「知名夜市」而要有具體名稱）。
        - 每個名稱應盡量對應單一 POI／場館／街區（必要時可用當地慣用簡稱）。
        - 輸出 4 到 8 個名稱，**僅**輸出 JSON 字串陣列，例如：["地點1","地點2"]
        """
    }
    
    /// 由地點 id 前綴還原興趣（避免 `nightlife_` 等被誤拆）；`supp_food_` 等補充列亦會還原為對應 `InterestTag`
    static func interestFromPlaceId(_ id: String) -> InterestTag? {
        var rest = id
        if rest.hasPrefix("supp_") {
            rest = String(rest.dropFirst("supp_".count))
        }
        let ordered = InterestTag.allCases.sorted { $0.rawValue.count > $1.rawValue.count }
        for t in ordered where rest.hasPrefix("\(t.rawValue)_") {
            return t
        }
        return nil
    }
    
    /// 將使用者勾選的地點 id 展平為生成 prompt 用短句（興趣：具體地名）
    static func flattenedPlacePromptLines(selectedIds: Set<String>, allAttractions: [SurroundingAttraction]) -> [String] {
        let byId = Dictionary(uniqueKeysWithValues: allAttractions.map { ($0.id, $0) })
        var lines: [String] = []
        for id in selectedIds.sorted() {
            guard let a = byId[id] else { continue }
            if id.hasPrefix("supp_"), let kind = InterestPreferenceSupplementKind.kindFromPlaceId(id) {
                let label = kind.promptLabelZh()
                lines.append("補充·\(label)：\(a.name)")
            } else if let tag = interestFromPlaceId(id) {
                lines.append("\(promptInterestLabel(tag))：\(a.name)")
            } else {
                lines.append(a.name)
            }
        }
        return lines
    }
}
