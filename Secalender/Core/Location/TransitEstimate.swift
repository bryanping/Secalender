//
//  TransitEstimate.swift
//  Secalender
//
//  城際交通粗估：區分市內／城際鐵路／航空／未知；航空含市區↔機場、報到、落地緩衝（不接外部 API 時的啟發式）。
//

import Foundation
import CoreLocation

// 修改内容：與生成引擎共用，供 Orchestrator / Prompt / 首日區塊轉換
enum TravelTransitMode: String, Codable, Sendable {
    case localGround
    case intercityRail
    case flight
    case unknown
}

struct TransitEstimate: Codable, Sendable {
    let mode: TravelTransitMode
    let totalSeconds: TimeInterval
    let summaryLine: String
    let breakdown: [String]
    
    /// 門到門總分鐘數（供 prompt 與 UI）
    var totalMinutes: Int { max(0, Int(totalSeconds / 60)) }
}

enum TransitEstimateCalculator {
    
    // MARK: - 對外 API（字串起訖，無 GPS 時仍可得保守估時）
    
    /// 依出發地／目的地文字與可選偏好推斷模式並估時（不接外部 API）
    static func estimateTransit(
        from origin: String,
        to destination: String,
        departureDate: Date?,
        preferredMode: TravelTransitMode?
    ) -> TransitEstimate {
        let o = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if o.isEmpty && d.isEmpty {
            return unknownEstimate(reason: "出發地與目的地皆為空")
        }
        if let mode = preferredMode, mode != .unknown {
            return estimateFromTextPair(origin: o, destination: d, forcedMode: mode)
        }
        return estimateFromTextPair(origin: o, destination: d, forcedMode: nil)
    }
    
    // MARK: - GPS 座標估時（主路徑）
    
    /// - Parameters:
    ///   - isInternational: 起訖是否跨國（由地理編碼 ISO 國碼比對）；若未知請傳 false，僅依距離分段。
    static func estimate(
        from: CLLocation,
        to: CLLocation,
        isInternational: Bool
    ) -> TransitEstimate {
        let d = from.distance(from: to)
        let km = d / 1000.0
        
        if isInternational {
            return flightEstimate(km: km, isInternational: true)
        }
        
        // 市內／短途地面：約 40 km 內
        if d <= 40_000 {
            let minutes = max(20, min(60, Int(22 + km * 1.15)))
            let sec = TimeInterval(minutes * 60)
            return TransitEstimate(
                mode: .localGround,
                totalSeconds: sec,
                summaryLine: "市內／短途地面約 \(minutes) 分鐘（直線約 \(Int(km)) 公里）",
                breakdown: [
                    "市區或近郊地面移動（公交／開車／計程混態）約 \(minutes) 分鐘",
                    "直線距離約 \(Int(km)) 公里（實際路徑可能更長）"
                ]
            )
        }
        
        // 同國城際：地面鐵路／新幹線級（約 40 km～900 km）
        if km <= 900 {
            let runHours = km / 250.0
            let runSec = runHours * 3600.0
            let stationBuffer: TimeInterval = 30 * 60 + 20 * 60
            let total = max(50 * 60, runSec + stationBuffer)
            let h = Int(total) / 3600
            let m = (Int(total) % 3600) / 60
            return TransitEstimate(
                mode: .intercityRail,
                totalSeconds: total,
                summaryLine: "城際鐵路／新幹線級約 \(h) 小時 \(m) 分（含進出站）",
                breakdown: [
                    "同國且距離約 \(Int(km)) 公里，依高速鐵路均速約 250 km/h 估算在途時間",
                    "提前到站、候車、進出站緩衝約 50 分鐘",
                    "實際車次、訂位與轉乘可能再增時，此為下限參考"
                ]
            )
        }
        
        // 同國超長距離（如烏魯木齊—上海）：改走航空啟發式
        return flightEstimate(km: km, isInternational: false)
    }
    
    // MARK: - 規劃請求合併（GPS + 文字跨國提示）
    
    /// 結合座標與文字線索，盡量判對跨國；無 GPS 時改以字串估時。
    static func estimateForPlanningRequest(
        departureLocation: CLLocation?,
        destinationDisplay: String,
        destinationLocation: CLLocation?,
        originISOCountryCode: String?,
        destinationISOCountryCode: String?,
        customInstructions: String?,
        startLocationText: String?
    ) -> TransitEstimate {
        let dest = destinationDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        let textOrigin = [startLocationText, inferOriginSnippet(from: customInstructions)]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        
        let textHintsIntl = inferInternationalFromText(origin: textOrigin, destination: dest)
        
        if let dep = departureLocation, let toLoc = destinationLocation {
            let oCC = originISOCountryCode ?? inferCountryISO(from: dep)
            let dCC = destinationISOCountryCode ?? inferCountryISO(from: toLoc) ?? inferCountryISO(from: Optional(dest))
            let ccIntl: Bool = {
                if let a = oCC, let b = dCC, a != b { return true }
                return textHintsIntl
            }()
            return estimate(from: dep, to: toLoc, isInternational: ccIntl)
        }
        
        // 有出發 GPS 但無目的地座標：仍以國碼／字串判跨國，避免被誤判成短途
        if departureLocation != nil, destinationLocation == nil {
            let destIso = destinationISOCountryCode ?? inferCountryISO(from: Optional(dest))
            let intl = (originISOCountryCode != nil && destIso != nil && originISOCountryCode != destIso)
                || textHintsIntl
            if intl {
                return flightEstimate(km: 2000, isInternational: true)
            }
            return TransitEstimate(
                mode: .intercityRail,
                totalSeconds: 3 * 3600 + 50 * 60,
                summaryLine: "城際交通約 3–4 小時（僅有出發座標時保守估）",
                breakdown: [
                    "無目的地精確座標，依同國長途鐵路啟發式",
                    "進出站與候車約 50 分鐘；在途約 3 小時（實際可能更長）"
                ]
            )
        }
        
        let mergedOrigin = textOrigin ?? ""
        return estimateTransit(from: mergedOrigin, to: dest, departureDate: nil, preferredMode: nil)
    }
    
    /// 僅文字時推斷跨國（關鍵字／國名）
    static func inferInternationalFromText(origin: String?, destination: String) -> Bool {
        let oc = inferCountryISO(from: origin)
        let dc = inferCountryISO(from: Optional(destination))
        if let a = oc, let b = dc, a != b { return true }
        if destination.contains("日本") || destination.contains("韩国") || destination.contains("韓國") {
            if let o = origin, (o.contains("中国") || o.contains("中國") || o.contains("上海") || o.contains("北京") || o.contains("广州") || o.contains("深圳")) {
                return true
            }
        }
        if destination.contains(" - ") {
            let parts = destination.components(separatedBy: " - ")
            if parts.count >= 2 {
                let c1 = inferCountryISO(from: parts.first.map { String($0) })
                let c2 = inferCountryISO(from: parts.last.map { String($0) })
                if let a = c1, let b = c2, a != b { return true }
            }
        }
        return false
    }

    /// 以經緯度粗判 ISO 國碼（避免 reverseGeocode 不穩）；僅涵蓋常見旅遊地
    static func roughISOCountryCode(for location: CLLocation) -> String? {
        inferCountryISO(from: location)
    }
    
    // MARK: - 私有
    
    private static func flightEstimate(km: Double, isInternational: Bool) -> TransitEstimate {
        let toDepartureAirport: TimeInterval = 75 * 60
        let checkInBuffer: TimeInterval = isInternational ? (180 * 60) : (120 * 60)
        let cruiseHoursRaw = km / 780.0
        let cruiseHours = max(cruiseHoursRaw, isInternational ? 1.25 : 0.75)
        let cruiseSec = cruiseHours * 3600.0
        let landingBuffer: TimeInterval = isInternational ? (90 * 60) : (50 * 60)
        let airportToCity: TimeInterval = 75 * 60
        let totalFlightLeg = toDepartureAirport + checkInBuffer + cruiseSec + landingBuffer + airportToCity
        
        let th = Int(totalFlightLeg) / 3600
        let tm = (Int(totalFlightLeg) % 3600) / 60
        return TransitEstimate(
            mode: .flight,
            totalSeconds: totalFlightLeg,
            summaryLine: "航空（含市區↔機場與報到）約 \(th) 小時 \(tm) 分",
            breakdown: [
                "前往出發機場（市區交通）約 75 分鐘",
                isInternational ? "國際線：建議提前 180 分鐘報到／安檢" : "國內線：建議提前 120 分鐘報到／安檢",
                "空中航行約 \(String(format: "%.1f", cruiseHours)) 小時（均速約 780 km/h，直線約 \(Int(km)) 公里）",
                isInternational ? "落地後入境、提領行李約 90 分鐘" : "落地後下機與行李約 50 分鐘",
                "目的地機場至市區／住宿約 75 分鐘"
            ]
        )
    }
    
    private static func estimateFromTextPair(origin: String, destination: String, forcedMode: TravelTransitMode?) -> TransitEstimate {
        if let f = forcedMode {
            switch f {
            case .localGround:
                return TransitEstimate(
                    mode: .localGround,
                    totalSeconds: 45 * 60,
                    summaryLine: "市內地面約 45 分鐘（使用者指定）",
                    breakdown: ["市內／短途地面移動約 45 分鐘（啟發式）"]
                )
            case .intercityRail:
                return TransitEstimate(
                    mode: .intercityRail,
                    totalSeconds: 3 * 3600,
                    summaryLine: "城際鐵路約 3 小時（使用者指定；無座標時保守估）",
                    breakdown: ["進出站與候車約 50 分鐘", "在途約 2 小時（無精確距離時之保守值）"]
                )
            case .flight:
                return flightEstimate(km: 2200, isInternational: true)
            case .unknown:
                break
            }
        }
        
        let intl = inferInternationalFromText(origin: origin.isEmpty ? nil : origin, destination: destination)
        if intl {
            return flightEstimate(km: 2000, isInternational: true)
        }
        return TransitEstimate(
            mode: .intercityRail,
            totalSeconds: 3 * 3600 + 50 * 60,
            summaryLine: "城際鐵路約 3–4 小時（無 GPS 時保守估）",
            breakdown: [
                "同國跨城：進出站與候車約 50 分鐘",
                "在途約 3 小時（無精確座標時之保守下限）"
            ]
        )
    }
    
    private static func unknownEstimate(reason: String) -> TransitEstimate {
        TransitEstimate(
            mode: .unknown,
            totalSeconds: 2 * 3600,
            summaryLine: "交通耗時不明，保守假設約 2 小時（\(reason)）",
            breakdown: ["請勿將首日景點排得過滿；若為長途／跨國，實際可能需半日以上"]
        )
    }
    
    private static func inferOriginSnippet(from custom: String?) -> String? {
        guard let c = custom, !c.isEmpty else { return nil }
        let patterns = ["出發地", "出发地", "從", "从", "由"]
        for p in patterns {
            if let r = c.range(of: p) {
                let tail = String(c[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let line = tail.components(separatedBy: .newlines).first ?? tail
                let s = line.trimmingCharacters(in: .whitespaces)
                if s.count >= 2, s.count <= 40 { return s }
            }
        }
        let cities = ["上海", "北京", "广州", "深圳", "杭州", "成都", "台北", "台中", "高雄", "香港", "新加坡", "東京", "大阪", "首爾", "首尔"]
        for city in cities where c.contains(city) { return city }
        return nil
    }
    
    /// 粗對應 ISO 3166-1 alpha-2（僅常見旅遊地）
    private static func inferCountryISO(from text: String?) -> String? {
        guard let t = text?.lowercased(), !t.isEmpty else { return nil }
        let map: [(String, String)] = [
            ("日本", "JP"), ("东京", "JP"), ("東京", "JP"), ("大阪", "JP"), ("京都", "JP"), ("北海道", "JP"), ("福冈", "JP"), ("福岡", "JP"),
            ("中国", "CN"), ("中國", "CN"), ("上海", "CN"), ("北京", "CN"), ("广州", "CN"), ("深圳", "CN"), ("杭州", "CN"), ("成都", "CN"),
            ("台湾", "TW"), ("台灣", "TW"), ("台北", "TW"), ("台中", "TW"), ("高雄", "TW"),
            ("香港", "HK"), ("澳门", "MO"), ("澳門", "MO"),
            ("韩国", "KR"), ("韓國", "KR"), ("首尔", "KR"), ("首爾", "KR"),
            ("美国", "US"), ("美國", "US"),
            ("法国", "FR"), ("法國", "FR"), ("巴黎", "FR"),
            ("英国", "GB"), ("英國", "GB"), ("伦敦", "GB"),
            ("泰国", "TH"), ("泰國", "TH"), ("曼谷", "TH"),
            ("新加坡", "SG")
        ]
        for (k, code) in map where t.contains(k.lowercased()) { return code }
        return nil
    }

    /// 以經緯度粗判國家（避免 reverseGeocode 不穩造成跨國判斷失效；僅涵蓋常見旅遊地）
    private static func inferCountryISO(from location: CLLocation) -> String? {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Japan (rough)
        if lat >= 24.0, lat <= 46.5, lon >= 122.5, lon <= 146.5 { return "JP" }
        // Taiwan
        if lat >= 21.5, lat <= 25.8, lon >= 119.0, lon <= 122.2 { return "TW" }
        // Hong Kong
        if lat >= 22.0, lat <= 22.7, lon >= 113.7, lon <= 114.5 { return "HK" }
        // South Korea
        if lat >= 33.0, lat <= 39.5, lon >= 124.0, lon <= 132.0 { return "KR" }
        // China (very rough mainland bbox)
        if lat >= 18.0, lat <= 54.0, lon >= 73.0, lon <= 135.0 { return "CN" }

        return nil
    }
}
