//
//  TravelInterestPlaceSuggester.swift
//  Secalender
//
//  依「興趣偏好」向資料庫與 OpenAI 取得真實可查的地點名稱，供勾選後寫入行程生成。
//

import Foundation

enum TravelInterestPlaceSuggester {
    
    private static func parseCityCountry(from destination: String) -> (city: String, country: String?) {
        if destination.contains(" - ") {
            let parts = destination.components(separatedBy: " - ")
            let country = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
            let city = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? destination
            return (city, country)
        }
        return (destination.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }
    
    /// 取得單一興趣下的建議地點（先 CityAttractionsDatabase，不足則 OpenAI 補齊）
    /// - Parameter idPrefixOverride: 非 nil 時用於地點 id 前綴（例如補充主題 `supp_food`），避免與主興趣列重複。
    static func fetchPlaces(
        destination: String,
        interest: InterestTag,
        excludeLowercasedNames: Set<String>,
        idPrefixOverride: String? = nil
    ) async throws -> [SurroundingAttraction] {
        let idPrefix = idPrefixOverride ?? interest.rawValue
        let (cityName, countryName) = parseCityCountry(from: destination)
        guard !cityName.isEmpty else { return [] }
        
        let database = CityAttractionsDatabase.shared
        let dbRows = database.getFilteredAttractions(
            for: cityName,
            country: countryName,
            interestTags: [interest.rawValue],
            sortBy: .popularity,
            referenceLocation: nil,
            routeLocations: [],
            excludeAttractions: [],
            maxDistance: nil,
            futureRouteLocations: []
        )
        
        var attractions: [SurroundingAttraction] = []
        var seenLower = Set<String>()
        
        for ca in dbRows {
            let lower = ca.name.lowercased()
            if excludeLowercasedNames.contains(lower) || seenLower.contains(lower) { continue }
            seenLower.insert(lower)
            attractions.append(SurroundingAttraction(
                id: "\(idPrefix)_\(ca.id)",
                name: ca.name,
                category: ca.category,
                icon: ca.icon
            ))
            if attractions.count >= 8 { return attractions }
        }
        
        if attractions.count < 4 {
            let countryLine = countryName.map { "（\($0)）" } ?? ""
            let prompt = TravelSpecialExperienceCatalog.openAIPromptForInterestPlaces(
                cityName: cityName,
                countryLine: countryLine,
                interest: interest
            )
            let response = try await OpenAIManager.shared.generateSurroundingAttractions(prompt: prompt, timeout: 30)
            let names = parseNameArray(from: response)
            var aiIndex = 0
            for name in names {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let lower = trimmed.lowercased()
                if excludeLowercasedNames.contains(lower) || seenLower.contains(lower) { continue }
                seenLower.insert(lower)
                let (category, icon) = inferCategoryAndIcon(from: trimmed)
                let id = "\(idPrefix)_ai_\(aiIndex)_\(UUID().uuidString.prefix(8))"
                aiIndex += 1
                attractions.append(SurroundingAttraction(id: id, name: trimmed, category: category, icon: icon))
                if attractions.count >= 8 { break }
            }
        }
        
        return Array(attractions.prefix(8))
    }
    
    /// 補充主題：六類興趣走 `fetchPlaces`；休憩／景點／親子／其他以 AI 依主題產生真實地名。
    static func fetchSupplementPlaces(
        destination: String,
        kind: InterestPreferenceSupplementKind,
        otherUserHint: String?,
        excludeLowercasedNames: Set<String>
    ) async throws -> [SurroundingAttraction] {
        if let tag = kind.interestTag {
            return try await fetchPlaces(
                destination: destination,
                interest: tag,
                excludeLowercasedNames: excludeLowercasedNames,
                idPrefixOverride: kind.placeIdPrefix
            )
        }
        let (cityName, countryName) = parseCityCountry(from: destination)
        guard !cityName.isEmpty else { return [] }
        let countryLine = countryName.map { "（\($0)）" } ?? ""
        let prompt = TravelSpecialExperienceCatalog.openAIPromptForSupplementKind(
            cityName: cityName,
            countryLine: countryLine,
            kind: kind,
            otherHint: otherUserHint
        )
        let response = try await OpenAIManager.shared.generateSurroundingAttractions(prompt: prompt, timeout: 30)
        let names = parseNameArray(from: response)
        let idPrefix = kind.placeIdPrefix
        var attractions: [SurroundingAttraction] = []
        var seenLower = excludeLowercasedNames
        var aiIndex = 0
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            if seenLower.contains(lower) { continue }
            seenLower.insert(lower)
            let (category, icon) = inferCategoryAndIcon(from: trimmed)
            let id = "\(idPrefix)_ai_\(aiIndex)_\(UUID().uuidString.prefix(8))"
            aiIndex += 1
            attractions.append(SurroundingAttraction(id: id, name: trimmed, category: category, icon: icon))
            if attractions.count >= 8 { break }
        }
        return attractions
    }
    
    // MARK: - 解析 OpenAI 回傳
    
    private static func parseNameArray(from jsonString: String) -> [String] {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return arr
        }
        if let start = trimmed.range(of: "["),
           let end = trimmed.range(of: "]", options: .backwards),
           let sub = String(trimmed[start.lowerBound..<end.upperBound]).data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: sub) as? [String] {
            return arr
        }
        if let data = trimmed.data(using: .utf8),
           let objs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return objs.compactMap { $0["name"] as? String }
        }
        return []
    }
    
    // MARK: - 分類推斷（與原週邊推薦邏輯一致）
    
    private static func inferCategoryAndIcon(from name: String) -> (category: String, icon: String) {
        let n = name.lowercased()
        if n.contains("塔") || n.contains("大樓") || n.contains("大厦") || n.contains("tower") || n.contains("building") {
            return ("地标", "building.2")
        }
        if n.contains("博物館") || n.contains("博物馆") || n.contains("美術館") || n.contains("美术馆") || n.contains("museum") || n.contains("gallery") {
            return ("文化", "book")
        }
        if n.contains("寺") || n.contains("廟") || n.contains("神社") || n.contains("temple") || n.contains("shrine") {
            return ("文化", "building.columns")
        }
        if n.contains("公園") || n.contains("公园") || n.contains("park") || n.contains("山") || n.contains("mountain") {
            return ("自然", "tree")
        }
        if n.contains("市場") || n.contains("市场") || n.contains("商店街") || n.contains("market") || n.contains("mall") {
            return ("购物", "bag")
        }
        if n.contains("美食") || n.contains("餐廳") || n.contains("餐厅") || n.contains("restaurant") || n.contains("food") {
            return ("美食", "fork.knife")
        }
        if n.contains("酒吧") || n.contains("夜店") || n.contains("夜景") || n.contains("bar") || n.contains("night") {
            return ("夜生活", "moon.stars")
        }
        return ("景点", "mappin.circle.fill")
    }
}
