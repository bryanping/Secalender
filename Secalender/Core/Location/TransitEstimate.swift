//
//  TransitEstimate.swift
//  Secalender
//
//  城際交通粗估：區分市內／城際鐵路／航空，航空含報到與機場往返緩衝（不接外部 API 時的啟發式）。
//

import Foundation
import CoreLocation

enum TravelTransitMode: String, Codable, Sendable {
    case localGround
    case intercityRail
    case flight
}

struct TransitEstimate: Codable, Sendable {
    let mode: TravelTransitMode
    let totalSeconds: TimeInterval
    let summaryLine: String
    let breakdown: [String]
}

enum TransitEstimateCalculator {
    /// - Parameters:
    ///   - isInternational: 起訖是否跨國（由地理編碼 ISO 國碼比對）；若未知請傳 false，僅依距離分段。
    static func estimate(
        from: CLLocation,
        to: CLLocation,
        isInternational: Bool
    ) -> TransitEstimate {
        let d = from.distance(from: to)
        let km = d / 1000.0

        if d <= 85_000 {
            let minutes = max(12, min(80, Int(18 + km * 2.0)))
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

        if !isInternational && km <= 1_200 {
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
                    "進站候車、進出站與月台步行約 50 分鐘",
                    "實際車次、訂位與轉乘可能再增時，此為下限參考"
                ]
            )
        }

        let toDepartureAirport: TimeInterval = 50 * 60
        let checkInBuffer: TimeInterval = isInternational ? (180 * 60) : (120 * 60)
        let cruiseHours = km / 780.0
        let cruiseSec = cruiseHours * 3600.0
        let landingBuffer: TimeInterval = isInternational ? (85 * 60) : (50 * 60)
        let airportToCity: TimeInterval = 75 * 60
        let totalFlightLeg = toDepartureAirport + checkInBuffer + cruiseSec + landingBuffer + airportToCity

        let th = Int(totalFlightLeg) / 3600
        let tm = (Int(totalFlightLeg) % 3600) / 60
        return TransitEstimate(
            mode: .flight,
            totalSeconds: totalFlightLeg,
            summaryLine: "航空（含市區↔機場與報到）約 \(th) 小時 \(tm) 分",
            breakdown: [
                "前往出發機場（市區交通）約 50 分鐘",
                isInternational ? "國際線：建議提前 180 分鐘報到／安檢" : "國內線：建議提前 120 分鐘報到／安檢",
                "空中航行約 \(String(format: "%.1f", cruiseHours)) 小時（均速約 780 km/h，直線 \(Int(km)) 公里）",
                isInternational ? "落地後入境、提領行李約 85 分鐘" : "落地後下機與行李約 50 分鐘",
                "目的地機場至市區／住宿約 75 分鐘"
            ]
        )
    }
}
