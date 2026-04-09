//
//  TravelTimeCalculator.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import CoreLocation
import MapKit
import UIKit

/// 交通模式（对应 Google Directions API 与用户偏好）
enum TravelMode: String {
    case transit = "transit"       // 公共交通
    case driving = "driving"       // 驾车/出租车
    case walking = "walking"       // 步行
}

/// 路程时间计算器
/// 支持：Apple MapKit（默认）、Google Directions API（国际）、高德地图（中国，需配置）
final class TravelTimeCalculator {
    static let shared = TravelTimeCalculator()
    private init() {}
    
    /// 准备时间（分钟）
    private let preparationTime: TimeInterval = 10 * 60 // 10分钟
    
    /// 计算路程时间（按用户交通偏好）
    /// - Parameters:
    ///   - from: 起始位置
    ///   - to: 目标位置
    ///   - mode: 交通方式（transit/driving）
    ///   - completion: 完成回调
    func calculateTravelTime(
        from: CLLocation,
        to: CLLocation,
        mode: TravelMode = .transit,
        completion: @escaping (TimeInterval?, TimeInterval?, String?) -> Void
    ) {
        switch mode {
        case .driving:
            calculateTaxiTime(from: from, to: to) { taxiTime in
                completion(taxiTime, taxiTime, "驾车约 \(Int((taxiTime ?? 0) / 60)) 分钟")
            }
        case .transit, .walking:
            calculateEfficientRoute(from: from, to: to, preferredMode: mode) { efficientTime, routeInfo in
                self.calculateTaxiTime(from: from, to: to) { taxiTime in
                    completion(efficientTime, taxiTime, routeInfo)
                }
            }
        }
    }
    
    /// 计算路程时间（兼容旧 API，默认公共交通）
    func calculateTravelTime(
        from: CLLocation,
        to: CLLocation,
        completion: @escaping (TimeInterval?, TimeInterval?, String?) -> Void
    ) {
        calculateTravelTime(from: from, to: to, mode: .transit, completion: completion)
    }
    
    /// 直線距離超過閾值時，開車／公交 API 常不適用；改走 `TransitEstimateCalculator` 分段估時。
    /// - Parameter isInternational: 未知時請 false，僅影響航空報到緩衝。
    /// - Returns: 若不需城際估算則為 nil（應走一般路網）
    static func intercityEstimateIfApplicable(from: CLLocation, to: CLLocation, isInternational: Bool = false) -> (seconds: TimeInterval, summary: String)? {
        let d = from.distance(from: to)
        guard d > 100_000 else { return nil }
        let est = TransitEstimateCalculator.estimate(from: from, to: to, isInternational: isInternational)
        return (est.totalSeconds, est.summaryLine)
    }
    
    /// 计算最有效率路线（优先 Google Directions API）
    private func calculateEfficientRoute(
        from: CLLocation,
        to: CLLocation,
        preferredMode: TravelMode = .transit,
        completion: @escaping (TimeInterval?, String?) -> Void
    ) {
        if let est = Self.intercityEstimateIfApplicable(from: from, to: to) {
            completion(est.seconds + preparationTime, est.summary)
            return
        }
        // 1. 尝试 Google Directions API（国际地区更准确，需在 Google Cloud 启用 Directions API）
        if !isInChina(), let apiKey = getGoogleAPIKey() {
            requestGoogleDirections(from: from, to: to, mode: preferredMode, apiKey: apiKey) { time, info in
                if let time = time {
                    completion(time + self.preparationTime, info)
                    return
                }
                self.calculateViaMapKit(from: from, to: to, preferredMode: preferredMode, completion: completion)
            }
            return
        }
        
        // 2. 中国地区：使用高德 Web API（需配置 AMap_Driving_Route_Search_API_KEY）
        if isInChina(), let apiKey = getAmapAPIKey() {
            requestAmapRoute(from: from, to: to, mode: preferredMode, apiKey: apiKey) { time, info in
                if let time = time {
                    completion(time + self.preparationTime, info)
                    return
                }
                self.calculateViaMapKit(from: from, to: to, preferredMode: preferredMode, completion: completion)
            }
            return
        }
        
        calculateViaMapKit(from: from, to: to, preferredMode: preferredMode, completion: completion)
    }
    
    /// 通过 Google Directions API 获取交通时间
    private func requestGoogleDirections(
        from: CLLocation,
        to: CLLocation,
        mode: TravelMode,
        apiKey: String,
        completion: @escaping (TimeInterval?, String?) -> Void
    ) {
        let origin = "\(from.coordinate.latitude),\(from.coordinate.longitude)"
        let destination = "\(to.coordinate.latitude),\(to.coordinate.longitude)"
        let modeStr = (mode == .transit) ? "transit" : "walking"
        // 对 transit 使用 departure_time=now 以获取实时公交信息
        let timeParam = (modeStr == "transit") ? "&departure_time=now" : ""
        let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(destination)&mode=\(modeStr)&key=\(apiKey)\(timeParam)"
        guard let url = URL(string: urlString) else {
            completion(nil, nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["status"] as? String == "OK",
                  let routes = json["routes"] as? [[String: Any]],
                  let firstRoute = routes.first,
                  let legs = firstRoute["legs"] as? [[String: Any]],
                  let firstLeg = legs.first,
                  let duration = firstLeg["duration"] as? [String: Any],
                  let durationValue = duration["value"] as? Int else {
                completion(nil, nil)
                return
            }
            let time = TimeInterval(durationValue)
            let durationText = duration["text"] as? String ?? "\(Int(time / 60)) 分钟"
            completion(time, "\(mode == .transit ? "公共交通" : "步行")约 \(durationText)")
        }.resume()
    }
    
    /// 通过 Apple MapKit 计算（备用）
    private func calculateViaMapKit(
        from: CLLocation,
        to: CLLocation,
        preferredMode: TravelMode,
        completion: @escaping (TimeInterval?, String?) -> Void
    ) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
        
        request.transportType = .walking
        let walkingDirections = MKDirections(request: request)
        walkingDirections.calculate { response, error in
            if let route = response?.routes.first {
                let walkingTime = route.expectedTravelTime
                let walkingDistance = route.distance
                
                if preferredMode == .transit {
                    request.transportType = .transit
                    let transitDirections = MKDirections(request: request)
                    transitDirections.calculate { transitResponse, _ in
                        if let transitRoute = transitResponse?.routes.first {
                            let transitTime = transitRoute.expectedTravelTime
                            if walkingTime < transitTime {
                                completion(walkingTime + self.preparationTime, "步行 \(Int(walkingDistance))米，约 \(Int(walkingTime / 60)) 分钟")
                            } else {
                                completion(transitTime + self.preparationTime, "公共交通约 \(Int(transitTime / 60)) 分钟")
                            }
                        } else {
                            completion(walkingTime + self.preparationTime, "步行 \(Int(walkingDistance))米，约 \(Int(walkingTime / 60)) 分钟")
                        }
                    }
                } else {
                    completion(walkingTime + self.preparationTime, "步行 \(Int(walkingDistance))米，约 \(Int(walkingTime / 60)) 分钟")
                }
            } else {
                let distance = from.distance(from: to)
                if let est = Self.intercityEstimateIfApplicable(from: from, to: to) {
                    completion(est.seconds + self.preparationTime, est.summary)
                } else {
                    let estimatedTime = (distance / 1000) * 12 * 60
                    completion(estimatedTime + self.preparationTime, "估算约 \(Int(estimatedTime / 60)) 分钟")
                }
            }
        }
    }
    
    private func getGoogleAPIKey() -> String? {
        if let key = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String,
           !key.isEmpty, key != "$(GOOGLE_MAPS_API_KEY)" { return key }
        if let path = Bundle.main.path(forResource: "GoogleService-Info.plist", ofType: nil),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["API_KEY"] as? String, !key.isEmpty { return key }
        return ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"]
    }
    
    private func getAmapAPIKey() -> String? {
        if let key = Bundle.main.infoDictionary?["AMap_Driving_Route_Search_API_KEY"] as? String,
           !key.isEmpty, key != "$(AMap_Driving_Route_Search_API_KEY)" { return key }
        return ProcessInfo.processInfo.environment["AMap_Driving_Route_Search_API_KEY"]
    }
    
    /// 高德路徑規劃（駕車 v5 / 步行 v3），座標格式：經度,緯度
    private func requestAmapRoute(
        from: CLLocation,
        to: CLLocation,
        mode: TravelMode,
        apiKey: String,
        completion: @escaping (TimeInterval?, String?) -> Void
    ) {
        let origin = "\(from.coordinate.longitude),\(from.coordinate.latitude)"
        let destination = "\(to.coordinate.longitude),\(to.coordinate.latitude)"
        
        switch mode {
        case .driving:
            requestAmapDriving(origin: origin, destination: destination, apiKey: apiKey, completion: completion)
        case .transit, .walking:
            requestAmapWalking(origin: origin, destination: destination, apiKey: apiKey, completion: completion)
        }
    }
    
    /// 高德駕車路徑規劃 v5
    private func requestAmapDriving(
        origin: String,
        destination: String,
        apiKey: String,
        completion: @escaping (TimeInterval?, String?) -> Void
    ) {
        let urlString = "https://restapi.amap.com/v5/direction/driving?origin=\(origin)&destination=\(destination)&key=\(apiKey)"
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else {
            completion(nil, nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["status"] as? String) == "1" || (json["infocode"] as? String) == "10000",
                  let route = json["route"] as? [String: Any],
                  let paths = route["paths"] as? [[String: Any]],
                  let firstPath = paths.first else {
                completion(nil, nil)
                return
            }
            let durationStr = firstPath["duration"] as? String ?? ""
            let durationSec = Int(durationStr) ?? 0
            let distanceStr = firstPath["distance"] as? String ?? "0"
            let distanceM = Int(distanceStr) ?? 0
            completion(TimeInterval(durationSec), "駕車約 \(durationSec / 60) 分鐘，\(distanceM / 1000) 公里")
        }.resume()
    }
    
    /// 高德步行路徑規劃 v3
    private func requestAmapWalking(
        origin: String,
        destination: String,
        apiKey: String,
        completion: @escaping (TimeInterval?, String?) -> Void
    ) {
        let urlString = "https://restapi.amap.com/v3/direction/walking?origin=\(origin)&destination=\(destination)&key=\(apiKey)"
        guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else {
            completion(nil, nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["status"] as? String) == "1" || (json["status"] as? Int) == 1,
                  let route = json["route"] as? [String: Any] else {
                completion(nil, nil)
                return
            }
            let pathData: [String: Any]?
            if let pathsArr = route["paths"] as? [[String: Any]], let first = pathsArr.first {
                pathData = first
            } else if let pathsObj = route["paths"] as? [String: Any] {
                pathData = pathsObj
            } else {
                pathData = nil
            }
            guard let path = pathData else {
                completion(nil, nil)
                return
            }
            let durationStr = path["duration"] as? String ?? ""
            let durationSec = Int(durationStr) ?? 0
            let distanceStr = path["distance"] as? String ?? "0"
            let distanceM = Int(distanceStr) ?? 0
            completion(TimeInterval(durationSec), "步行約 \(durationSec / 60) 分鐘，\(distanceM) 米")
        }.resume()
    }
    
    /// 计算打车时间（中国用高德驾车 API）
    private func calculateTaxiTime(
        from: CLLocation,
        to: CLLocation,
        completion: @escaping (TimeInterval?) -> Void
    ) {
        if isInChina(), let apiKey = getAmapAPIKey() {
            let origin = "\(from.coordinate.longitude),\(from.coordinate.latitude)"
            let destination = "\(to.coordinate.longitude),\(to.coordinate.latitude)"
            requestAmapDriving(origin: origin, destination: destination, apiKey: apiKey) { time, _ in
                completion(time.map { $0 + self.preparationTime })
            }
            return
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let route = response?.routes.first {
                completion(route.expectedTravelTime + self.preparationTime)
            } else {
                let distance = from.distance(from: to)
                if let est = Self.intercityEstimateIfApplicable(from: from, to: to) {
                    completion(est.seconds + self.preparationTime)
                } else {
                    let estimatedTime = (distance / 1000) * 2 * 60
                    completion(estimatedTime + self.preparationTime)
                }
            }
        }
    }
    
    /// 打开地图应用导航
    /// - Parameters:
    ///   - destination: 目标位置
    ///   - transportType: 交通方式（walking, driving, transit）
    func openMapNavigation(
        destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType = .automobile
    ) {
        let destinationItem = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        destinationItem.name = "目的地"
        
        var launchOptions: [String: Any] = [:]
        
        switch transportType {
        case .walking:
            launchOptions[MKLaunchOptionsDirectionsModeKey] = MKLaunchOptionsDirectionsModeWalking
        case .automobile:
            launchOptions[MKLaunchOptionsDirectionsModeKey] = MKLaunchOptionsDirectionsModeDriving
        case .transit:
            launchOptions[MKLaunchOptionsDirectionsModeKey] = MKLaunchOptionsDirectionsModeTransit
        default:
            launchOptions[MKLaunchOptionsDirectionsModeKey] = MKLaunchOptionsDirectionsModeDriving
        }
        
        // 尝试打开Apple地图
        if MKMapItem.openMaps(with: [destinationItem], launchOptions: launchOptions) {
            return
        }
        
        // 如果在中国，尝试打开高德地图
        if isInChina() {
            let amapUrl = "iosamap://navi?sourceApplication=secalender&lat=\(destination.latitude)&lon=\(destination.longitude)&dev=0&style=2"
            if let url = URL(string: amapUrl), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        
        // 尝试打开Google Maps
        let googleMapsUrl = "comgooglemaps://?daddr=\(destination.latitude),\(destination.longitude)&directionsmode=driving"
        if let url = URL(string: googleMapsUrl), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }
        
        // 最后使用Apple地图
        destinationItem.openInMaps(launchOptions: launchOptions)
    }
    
    private func isInChina() -> Bool {
        let timeZone = TimeZone.current
        return timeZone.identifier.contains("Asia/Shanghai") || timeZone.identifier.contains("Asia/Chongqing")
    }
}

// MARK: - TransportPreference 映射
extension TravelMode {
    init(from transportPreference: TransportPreference?) {
        switch transportPreference {
        case .taxi:
            self = .driving
        case .walking:
            self = .walking
        default:
            self = .transit
        }
    }
}
