//
//  MapAppManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import CoreLocation
import MapKit
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
    
    /// 地图应用的 URL Scheme（用于检测是否已安装；Apple 使用 maps:// 以直接打开 App）
    var urlScheme: String {
        switch self {
        case .amap: return "iosamap://"
        case .baidu: return "baidumap://"
        case .apple: return "maps://"
        case .google: return "comgooglemaps://"
        }
    }
    
    /// 检查应用是否已安装（Apple 地图为系统内置，始终视为可用）
    var isInstalled: Bool {
        if self == .apple { return true }
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
    
    /// 打开指定地图应用（直接跳转 App，填入地址并可选显示路线/距离）
    /// - Parameters:
    ///   - mapApp: 地图应用类型
    ///   - destination: 目的地地址（字符串）
    ///   - coordinate: 目的地坐标（可选，优先使用）
    ///   - transportType: 交通方式（可选）；传入时以「导航/路线」模式打开并显示距离路段，不传则仅打开并定位到目的地
    func openMapApp(_ mapApp: MapAppType, destination: String, coordinate: CLLocationCoordinate2D? = nil, transportType: MKDirectionsTransportType? = nil) {
        let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        let wantDirections = (transportType != nil)
        
        var urlString: String?
        
        switch mapApp {
        case .amap:
            // 高德：path 为路线规划，t=0 驾车 t=2 步行；无 transportType 时也用 path 只填终点
            let t: Int
            if let type = transportType {
                t = (type == .walking) ? 2 : 0  // 0 驾车, 2 步行
            } else {
                t = 0
            }
            if let coord = coordinate {
                urlString = "iosamap://path?sourceApplication=Secalender&dlat=\(coord.latitude)&dlon=\(coord.longitude)&dname=\(encodedDestination)&dev=0&t=\(t)"
            } else {
                urlString = "iosamap://path?sourceApplication=Secalender&dname=\(encodedDestination)&dev=0&t=\(t)"
            }
            
        case .baidu:
            if let coord = coordinate {
                let mode = (transportType == .walking) ? "walking" : "driving"
                urlString = "baidumap://map/direction?destination=name:\(encodedDestination)|latlng:\(coord.latitude),\(coord.longitude)&mode=\(mode)&src=Secalender"
            } else {
                let mode = (transportType == .walking) ? "walking" : "driving"
                urlString = "baidumap://map/direction?destination=\(encodedDestination)&mode=\(mode)&src=Secalender"
            }
            
        case .apple:
            // 使用 maps:// 直接打开 Apple 地图 App，避免跳到网页
            if wantDirections {
                if let coord = coordinate {
                    urlString = "maps://?daddr=\(coord.latitude),\(coord.longitude)&dirflg=\(appleDirflg(transportType!))"
                } else {
                    urlString = "maps://?daddr=\(encodedDestination)&dirflg=\(appleDirflg(transportType!))"
                }
            } else {
                if let coord = coordinate {
                    urlString = "maps://?daddr=\(coord.latitude),\(coord.longitude)"
                } else {
                    urlString = "maps://?q=\(encodedDestination)"
                }
            }
            
        case .google:
            if wantDirections {
                if let coord = coordinate {
                    urlString = "comgooglemaps://?daddr=\(coord.latitude),\(coord.longitude)&dirflg=\(googleDirflg(transportType!))"
                } else {
                    urlString = "comgooglemaps://?daddr=\(encodedDestination)&dirflg=\(googleDirflg(transportType!))"
                }
            } else {
                if let coord = coordinate {
                    urlString = "comgooglemaps://?q=\(encodedDestination)&center=\(coord.latitude),\(coord.longitude)"
                } else {
                    urlString = "comgooglemaps://?q=\(encodedDestination)"
                }
            }
        }
        
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            if mapApp != .apple {
                openMapApp(.apple, destination: destination, coordinate: coordinate, transportType: transportType)
            }
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            if mapApp != .apple {
                openMapApp(.apple, destination: destination, coordinate: coordinate, transportType: transportType)
            } else {
                // Apple 地图备用：仍用 maps:// 尝试打开本机 App，不再用 https 避免开浏览器
                if let fallback = URL(string: urlString) {
                    UIApplication.shared.open(fallback, options: [:], completionHandler: nil)
                }
            }
        }
    }
    
    private func appleDirflg(_ type: MKDirectionsTransportType) -> String {
        switch type {
        case .walking: return "w"
        case .transit: return "r"
        default: return "d"
        }
    }
    
    private func googleDirflg(_ type: MKDirectionsTransportType) -> String {
        switch type {
        case .walking: return "w"
        case .transit: return "r"
        default: return "d"
        }
    }
}
