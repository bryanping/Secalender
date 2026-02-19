//
//  LocationCacheManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import CoreLocation

/// 位置缓存管理器 - 用于本地存储最后一次GPS定位位置
final class LocationCacheManager {
    static let shared = LocationCacheManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let lastLocationLatitudeKey = "last_location_latitude"
    private let lastLocationLongitudeKey = "last_location_longitude"
    private let lastLocationTimestampKey = "last_location_timestamp"
    private let lastLocationCountryKey = "last_location_country"  // 用户所在国家（中文）
    
    /// 保存最后一次GPS定位位置
    func saveLastLocation(_ location: CLLocation) {
        userDefaults.set(location.coordinate.latitude, forKey: lastLocationLatitudeKey)
        userDefaults.set(location.coordinate.longitude, forKey: lastLocationLongitudeKey)
        userDefaults.set(Date(), forKey: lastLocationTimestampKey)
        print("✅ 已保存最后一次GPS位置: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
    }
    
    /// 保存用户所在国家（中文）
    func saveUserCountry(_ country: String) {
        userDefaults.set(country, forKey: lastLocationCountryKey)
        print("✅ 已保存用户所在国家: \(country)")
    }
    
    /// 加载用户所在国家（中文）
    func loadUserCountry() -> String? {
        return userDefaults.string(forKey: lastLocationCountryKey)
    }
    
    /// 清除用户所在国家
    func clearUserCountry() {
        userDefaults.removeObject(forKey: lastLocationCountryKey)
    }
    
    /// 加载最后一次GPS定位位置
    func loadLastLocation() -> CLLocationCoordinate2D? {
        let latitude = userDefaults.double(forKey: lastLocationLatitudeKey)
        let longitude = userDefaults.double(forKey: lastLocationLongitudeKey)
        
        // 检查是否为有效坐标（不是0,0）
        guard latitude != 0 || longitude != 0 else {
            return nil
        }
        
        // 检查位置是否过期（超过30天认为过期）
        if let timestamp = userDefaults.object(forKey: lastLocationTimestampKey) as? Date {
            let daysSinceUpdate = Date().timeIntervalSince(timestamp) / (24 * 60 * 60)
            if daysSinceUpdate > 30 {
                print("⚠️ 最后一次GPS位置已过期（\(Int(daysSinceUpdate))天前），将重新定位")
                return nil
            }
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        print("✅ 已加载最后一次GPS位置: (\(latitude), \(longitude))")
        return coordinate
    }
    
    /// 清除缓存的位置
    func clearLastLocation() {
        userDefaults.removeObject(forKey: lastLocationLatitudeKey)
        userDefaults.removeObject(forKey: lastLocationLongitudeKey)
        userDefaults.removeObject(forKey: lastLocationTimestampKey)
        print("✅ 已清除GPS位置缓存")
    }
    
    /// 清除所有位置相关缓存（包括国家）
    func clearAllLocationCache() {
        clearLastLocation()
        clearUserCountry()
    }
}
