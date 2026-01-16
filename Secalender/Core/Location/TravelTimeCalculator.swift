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

/// 路程时间计算器
final class TravelTimeCalculator {
    static let shared = TravelTimeCalculator()
    private init() {}
    
    /// 准备时间（分钟）
    private let preparationTime: TimeInterval = 10 * 60 // 10分钟
    
    /// 计算路程时间
    /// - Parameters:
    ///   - from: 起始位置
    ///   - to: 目标位置
    ///   - completion: 完成回调，返回（最有效率时间（秒），打车时间（秒），路线信息）
    func calculateTravelTime(
        from: CLLocation,
        to: CLLocation,
        completion: @escaping (TimeInterval?, TimeInterval?, String?) -> Void
    ) {
        // 计算最有效率路线（步行或公共交通）
        calculateEfficientRoute(from: from, to: to) { efficientTime, routeInfo in
            // 计算打车时间
            self.calculateTaxiTime(from: from, to: to) { taxiTime in
                completion(efficientTime, taxiTime, routeInfo)
            }
        }
    }
    
    /// 计算最有效率路线
    private func calculateEfficientRoute(
        from: CLLocation,
        to: CLLocation,
        completion: @escaping (TimeInterval?, String?) -> Void
    ) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
        
        // 尝试步行
        request.transportType = .walking
        let walkingDirections = MKDirections(request: request)
        walkingDirections.calculate { response, error in
            if let route = response?.routes.first {
                let walkingTime = route.expectedTravelTime
                let walkingDistance = route.distance
                
                // 尝试公共交通
                request.transportType = .transit
                let transitDirections = MKDirections(request: request)
                transitDirections.calculate { transitResponse, transitError in
                    if let transitRoute = transitResponse?.routes.first {
                        let transitTime = transitRoute.expectedTravelTime
                        let transitDistance = transitRoute.distance
                        
                        // 选择时间更短的
                        if walkingTime < transitTime {
                            let totalTime = walkingTime + self.preparationTime
                            let routeInfo = "步行 \(Int(walkingDistance))米，约 \(Int(walkingTime / 60)) 分钟"
                            completion(totalTime, routeInfo)
                        } else {
                            let totalTime = transitTime + self.preparationTime
                            let routeInfo = "公共交通约 \(Int(transitTime / 60)) 分钟"
                            completion(totalTime, routeInfo)
                        }
                    } else {
                        // 只有步行可用
                        let totalTime = walkingTime + self.preparationTime
                        let routeInfo = "步行 \(Int(walkingDistance))米，约 \(Int(walkingTime / 60)) 分钟"
                        completion(totalTime, routeInfo)
                    }
                }
            } else {
                // 如果无法计算，使用直线距离估算
                let distance = from.distance(from: to)
                let estimatedTime = (distance / 1000) * 12 * 60 // 假设步行速度 5km/h
                let totalTime = estimatedTime + self.preparationTime
                let routeInfo = "估算约 \(Int(totalTime / 60)) 分钟"
                completion(totalTime, routeInfo)
            }
        }
    }
    
    /// 计算打车时间
    private func calculateTaxiTime(
        from: CLLocation,
        to: CLLocation,
        completion: @escaping (TimeInterval?) -> Void
    ) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.coordinate))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let route = response?.routes.first {
                let taxiTime = route.expectedTravelTime + self.preparationTime
                completion(taxiTime)
            } else {
                // 如果无法计算，使用直线距离估算（假设平均车速 30km/h）
                let distance = from.distance(from: to)
                let estimatedTime = (distance / 1000) * 2 * 60 // 假设平均车速 30km/h
                completion(estimatedTime + self.preparationTime)
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
