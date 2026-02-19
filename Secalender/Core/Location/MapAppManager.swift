//
//  MapAppManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import CoreLocation
import UIKit

/// 地图应用类型
enum MapAppType: String, CaseIterable {
    case amap = "高德地图"
    case baidu = "百度地图"
    case apple = "Apple地图"
    case google = "Google地图"
    
    /// 地图应用的图标名称
    var iconName: String {
        switch self {
        case .amap: return "map.fill"
        case .baidu: return "map.fill"
        case .apple: return "map.fill"
        case .google: return "map.fill"
        }
    }
    
    /// 地图应用的 URL Scheme
    var urlScheme: String {
        switch self {
        case .amap: return "iosamap://"
        case .baidu: return "baidumap://"
        case .apple: return "http://maps.apple.com/"
        case .google: return "comgooglemaps://"
        }
    }
    
    /// 检查应用是否已安装
    var isInstalled: Bool {
        guard let url = URL(string: urlScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

/// 地图应用管理器
/// 用于处理不同地图应用的跳转
class MapAppManager {
    static let shared = MapAppManager()
    
    private init() {}
    
    /// 获取可用的地图应用列表
    func getAvailableMapApps() -> [MapAppType] {
        return MapAppType.allCases.filter { $0.isInstalled || $0 == .apple }
    }
    
    /// 打开指定地图应用
    /// - Parameters:
    ///   - mapApp: 地图应用类型
    ///   - destination: 目的地地址（字符串）
    ///   - coordinate: 目的地坐标（可选，优先使用）
    func openMapApp(_ mapApp: MapAppType, destination: String, coordinate: CLLocationCoordinate2D? = nil) {
        let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        
        var urlString: String?
        
        switch mapApp {
        case .amap:
            if let coord = coordinate {
                // 使用坐标导航
                urlString = "iosamap://navi?sourceApplication=Secalender&lat=\(coord.latitude)&lon=\(coord.longitude)&dev=0&style=2"
            } else {
                // 使用地址搜索
                urlString = "iosamap://path?sourceApplication=Secalender&dname=\(encodedDestination)"
            }
            
        case .baidu:
            if let coord = coordinate {
                // 使用坐标导航
                urlString = "baidumap://map/direction?destination=\(coord.latitude),\(coord.longitude)&mode=driving&src=Secalender"
            } else {
                // 使用地址搜索
                urlString = "baidumap://map/search?query=\(encodedDestination)&src=Secalender"
            }
            
        case .apple:
            if let coord = coordinate {
                // 使用坐标
                urlString = "http://maps.apple.com/?daddr=\(coord.latitude),\(coord.longitude)"
            } else {
                // 使用地址搜索
                urlString = "http://maps.apple.com/?q=\(encodedDestination)"
            }
            
        case .google:
            if let coord = coordinate {
                // 使用坐标导航
                urlString = "comgooglemaps://?daddr=\(coord.latitude),\(coord.longitude)&directionsmode=driving"
            } else {
                // 使用地址搜索
                urlString = "comgooglemaps://?q=\(encodedDestination)"
            }
        }
        
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            // 如果无法构建 URL，尝试使用 Apple 地图作为备用
            if mapApp != .apple {
                openMapApp(.apple, destination: destination, coordinate: coordinate)
            }
            return
        }
        
        // 检查是否可以打开 URL
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            // 如果无法打开，尝试使用 Apple 地图作为备用
            if mapApp != .apple {
                openMapApp(.apple, destination: destination, coordinate: coordinate)
            } else {
                // 如果 Apple 地图也无法打开，尝试使用网页版
                if let coord = coordinate {
                    let webUrl = URL(string: "https://maps.apple.com/?daddr=\(coord.latitude),\(coord.longitude)")
                    if let webUrl = webUrl {
                        UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
                    }
                } else {
                    let webUrl = URL(string: "https://maps.apple.com/?q=\(encodedDestination)")
                    if let webUrl = webUrl {
                        UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
                    }
                }
            }
        }
    }
}
