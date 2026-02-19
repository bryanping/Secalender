//
//  NearbyEventsView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/29.
//

import SwiftUI
import MapKit
import CoreLocation

struct NearbyEventsView: View {
    @StateObject private var locationManager = NearbyLocationManager()
    @State private var region: MKCoordinateRegion = {
        // 从本地缓存加载最后一次GPS位置作为初始值
        if let lastCoordinate = LocationCacheManager.shared.loadLastLocation() {
            return MKCoordinateRegion(
                center: lastCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        // 如果没有缓存，使用默认值（稍后会被GPS更新）
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    }()
    @State private var isLocating = true
    @State private var locationError: String?

    var body: some View {
        ZStack {
            if isLocating {
                // 定位中显示加载指示器
                ProgressView("nearby_events.locating".localized())
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
            } else if let error = locationError {
                // 定位失败显示错误提示
                VStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("nearby_events.retry".localized()) {
                        Task {
                            await requestLocationAndUpdate()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(10)
            }
            
            Map(coordinateRegion: $region, interactionModes: [.all], showsUserLocation: true)
                .edgesIgnoringSafeArea(.all)
        }
        .task {
            // 请求位置权限并获取实时GPS位置
            await requestLocationAndUpdate()
        }
    }
    
    /// 请求位置权限并获取实时GPS位置（参考苹果地图和高德地图的做法）
    private func requestLocationAndUpdate() async {
        isLocating = true
        locationError = nil
        
        // 请求位置权限
        locationManager.requestPermission()
        
        // 等待位置更新（最多等待5秒）
        let startTime = Date()
        while locationManager.currentLocation == nil && Date().timeIntervalSince(startTime) < 5.0 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        // 获取GPS位置
        if let currentLocation = locationManager.currentLocation {
            let coordinate = currentLocation.coordinate
            // 保存到本地缓存
            LocationCacheManager.shared.saveLastLocation(currentLocation)
            
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            isLocating = false
        } else {
            // GPS定位失败，尝试使用 requestLocation（一次性定位，更省电）
            if let location = await locationManager.requestLocationOnce() {
                let coordinate = location.coordinate
                // 保存到本地缓存
                LocationCacheManager.shared.saveLastLocation(location)
                
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                isLocating = false
            } else if locationManager.currentLocation != nil {
                // 如果 requestLocationOnce 失败但 currentLocation 有值，使用它
                let location = locationManager.currentLocation!
                let coordinate = location.coordinate
                // 保存到本地缓存
                LocationCacheManager.shared.saveLastLocation(location)
                
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                isLocating = false
            } else {
                // 定位失败，尝试使用缓存的位置
                if let cachedCoordinate = LocationCacheManager.shared.loadLastLocation() {
                    print("📍 使用缓存的GPS位置")
                    region = MKCoordinateRegion(
                        center: cachedCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                    isLocating = false
                } else {
                    // 定位失败且无缓存，显示错误提示
                    locationError = "nearby_events.location_error".localized()
                    isLocating = false
                    print("⚠️ GPS定位失败，无法获取当前位置")
                }
            }
        }
    }
}

// MARK: - 附近事件位置管理器（参考苹果地图和高德地图的GPS定位方式）
class NearbyLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    
    override init() {
        super.init()
        manager.delegate = self
        // 使用最佳精度，类似苹果地图和高德地图
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // 设置距离过滤器，减少不必要的更新
        manager.distanceFilter = 10 // 10米
    }
    
    func requestPermission() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            #if os(iOS)
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                // 先尝试使用 startUpdatingLocation 获取位置
                manager.startUpdatingLocation()
            }
            #else
            if status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
            #endif
        }
    }
    
    /// 一次性定位请求（类似苹果地图和高德地图的做法，更省电）
    func requestLocationOnce() async -> CLLocation? {
        let status = manager.authorizationStatus
        #if os(iOS)
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return nil
        }
        #else
        guard status == .authorizedAlways else {
            return nil
        }
        #endif
        
        // 使用 requestLocation 进行一次性定位
        if #available(iOS 14.0, *) {
            return await withCheckedContinuation { continuation in
                locationContinuation = continuation
                manager.requestLocation()
            }
        } else {
            // iOS 14 以下使用 startUpdatingLocation
            manager.startUpdatingLocation()
            // 等待位置更新
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 等待2秒
            return currentLocation
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        // 验证位置精度（类似苹果地图和高德地图的验证）
        if location.horizontalAccuracy > 0 && location.horizontalAccuracy < 100 {
            // 精度在100米以内，认为是有效位置
            currentLocation = location
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        } else if location.horizontalAccuracy > 0 {
            // 精度较差，但可以使用
            currentLocation = location
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
        
        // 获取到位置后停止更新以节省电量
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置获取失败: \(error.localizedDescription)")
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        #if os(iOS)
        if #available(iOS 14.0, *) {
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        } else {
            if status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
        #else
        if status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
        #endif
    }
}
