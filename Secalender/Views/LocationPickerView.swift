//
//  LocationPickerView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import MapKit
import CoreLocation
import Contacts
#if canImport(UIKit)
import UIKit
#endif

struct LocationPickerView: View {
    @Binding var selectedAddress: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) var dismiss
    
    @State private var region: MKCoordinateRegion = {
        // 从本地缓存加载最后一次GPS位置作为初始值
        if let lastCoordinate = LocationCacheManager.shared.loadLastLocation() {
            return MKCoordinateRegion(
                center: lastCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        // 如果没有缓存，使用默认值（稍后会被GPS更新）
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }()
    @State private var isLocating = true
    @State private var locationError: String?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""
    @State private var locationAddress = ""
    @StateObject private var locationManager = LocationPickerManager()
    @State private var isUpdatingLocation = false
    @State private var isViewActive = true
    @State private var currentGeocoder: CLGeocoder?
    @State private var pendingUpdateTask: DispatchWorkItem?
    @State private var pendingSearchTask: DispatchWorkItem?
    @State private var shouldShowMap = false // 控制 Map 的显示，避免在视图销毁时渲染
    @FocusState private var isSearchFieldFocused: Bool // 控制搜索栏焦点状态
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索地点", text: $searchText)
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            searchLocation()
                        }
                        .onChange(of: searchText) { oldValue, newValue in
                            // 添加搜索防抖，避免频繁搜索
                            debounceSearch()
                        }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                // 搜索结果列表
                if !searchResults.isEmpty {
                    List {
                        ForEach(searchResults, id: \.self) { item in
                            Button(action: {
                                selectLocation(item: item)
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "未知地点")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if let address = formatAddress(from: item.placemark) {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                
                // 地图视图
                ZStack {
                    if isLocating {
                        // 定位中显示加载指示器
                        ProgressView("正在定位...")
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
                            Button("重试") {
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
                    
                    // 地图视图（始终显示，除非视图已销毁）
                    if shouldShowMap {
                        // 使用优化的 Map 渲染
                        Map(coordinateRegion: $region,
                            interactionModes: [.pan, .zoom],
                            showsUserLocation: true,
                            userTrackingMode: .none)
                        .onChange(of: region.center.latitude) { oldValue, newValue in
                            // 地图移动时更新选中位置（避免频繁更新）
                            guard isViewActive, !isUpdatingLocation else { return }
                            // 检查坐标变化是否足够大（约 10 米）
                            guard abs(oldValue - newValue) > 0.0001 else { return }
                            updateLocationFromRegion()
                        }
                        .onChange(of: region.center.longitude) { oldValue, newValue in
                            // 地图移动时更新选中位置（避免频繁更新）
                            guard isViewActive, !isUpdatingLocation else { return }
                            // 检查坐标变化是否足够大（约 10 米）
                            guard abs(oldValue - newValue) > 0.0001 else { return }
                            updateLocationFromRegion()
                        }
                        
                        // 中心标记（仅保留中心红点）
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                            .offset(y: -20)
                            .allowsHitTesting(false) // 不拦截触摸事件
                    }
                }
                
                // 底部按钮
                VStack(spacing: 12) {
                    if !locationName.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(locationName)
                                .font(.headline)
                            if !locationAddress.isEmpty {
                                Text(locationAddress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    HStack(spacing: 16) {
                        Button("取消") {
                            cleanupAndDismiss()
                        }
                        .foregroundColor(.secondary)
                        
                        Button("确认") {
                            if !locationAddress.isEmpty {
                                selectedAddress = locationAddress
                                selectedCoordinate = selectedLocation
                            }
                            cleanupAndDismiss()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(locationAddress.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(10)
                        .disabled(locationAddress.isEmpty)
                    }
                }
                .padding()
            }
            .navigationTitle("选择地点")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                // 视图出现时立即显示 Map
                isViewActive = true
                // 使用 Task 确保在主线程执行
                Task { @MainActor in
                    shouldShowMap = true
                    // 延迟聚焦搜索栏，确保视图完全加载后打开键盘
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 秒
                    isSearchFieldFocused = true
                }
            }
            .onDisappear {
                // 视图消失时立即隐藏 Map 并清理资源
                shouldShowMap = false
                isSearchFieldFocused = false // 移除焦点，关闭键盘
                cleanupResources()
            }
            .task {
                // 请求位置权限并获取实时GPS位置
                guard isViewActive else { return }
                await requestLocationAndUpdate()
            }
        }
    }
    
    /// 请求位置权限并获取实时GPS位置（参考苹果地图和高德地图的做法）
    @MainActor
    private func requestLocationAndUpdate() async {
        guard isViewActive else { return }
        
        isLocating = true
        locationError = nil
        
        // 如果有已选择的坐标，使用它
        if let coordinate = selectedCoordinate {
            guard isViewActive else { return }
            isUpdatingLocation = true
            region.center = coordinate
            selectedLocation = coordinate
            reverseGeocode(coordinate: coordinate)
            isUpdatingLocation = false
            isLocating = false
            return
        }
        
        // 请求位置权限
        locationManager.requestPermission()
        
        // 等待位置更新（最多等待5秒）
        let startTime = Date()
        while locationManager.currentLocation == nil && Date().timeIntervalSince(startTime) < 5.0 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            guard isViewActive, shouldShowMap else { return }
        }
        
        guard isViewActive, shouldShowMap else { return }
        
        // 获取GPS位置
        if let currentLocation = locationManager.currentLocation {
            let coordinate = currentLocation.coordinate
            // 保存到本地缓存
            LocationCacheManager.shared.saveLastLocation(currentLocation)
            
            guard isViewActive, shouldShowMap else { return }
            isUpdatingLocation = true
            region.center = coordinate
            selectedLocation = coordinate
            reverseGeocode(coordinate: coordinate)
            isUpdatingLocation = false
            isLocating = false
        } else {
            // GPS定位失败，尝试使用 requestLocation（一次性定位，更省电）
            if let location = await locationManager.requestLocationOnce() {
                guard isViewActive, shouldShowMap else { return }
                let coordinate = location.coordinate
                // 保存到本地缓存
                LocationCacheManager.shared.saveLastLocation(location)
                
                isUpdatingLocation = true
                region.center = coordinate
                selectedLocation = coordinate
                reverseGeocode(coordinate: coordinate)
                isUpdatingLocation = false
                isLocating = false
            } else if locationManager.currentLocation != nil {
                guard isViewActive, shouldShowMap else { return }
                // 如果 requestLocationOnce 失败但 currentLocation 有值，使用它
                let location = locationManager.currentLocation!
                let coordinate = location.coordinate
                // 保存到本地缓存
                LocationCacheManager.shared.saveLastLocation(location)
                
                isUpdatingLocation = true
                region.center = coordinate
                selectedLocation = coordinate
                reverseGeocode(coordinate: coordinate)
                isUpdatingLocation = false
                isLocating = false
            } else {
                guard isViewActive, shouldShowMap else { return }
                // 定位失败，尝试使用缓存的位置
                if let cachedCoordinate = LocationCacheManager.shared.loadLastLocation() {
                    print("📍 使用缓存的GPS位置")
                    isUpdatingLocation = true
                    region.center = cachedCoordinate
                    selectedLocation = cachedCoordinate
                    reverseGeocode(coordinate: cachedCoordinate)
                    isUpdatingLocation = false
                    isLocating = false
                } else {
                    // 定位失败且无缓存，显示错误提示
                    locationError = "无法获取当前位置，请检查定位权限设置"
                    isLocating = false
                    print("⚠️ GPS定位失败，无法获取当前位置")
                }
            }
        }
    }
    
    @MainActor
    private func updateLocationFromRegion() {
        // 检查视图是否仍然活跃
        guard isViewActive, shouldShowMap else { return }
        
        // 取消之前的延迟任务
        pendingUpdateTask?.cancel()
        
        // 延迟更新，避免频繁触发（增加到 0.5 秒以减少请求频率）
        let task = DispatchWorkItem { [self] in
            guard self.isViewActive,
                  self.shouldShowMap,
                  !self.isUpdatingLocation else { return }
            let coordinate = self.region.center
            self.selectedLocation = coordinate
            self.reverseGeocode(coordinate: coordinate)
        }
        pendingUpdateTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }
    
    /// 搜索防抖处理
    private func debounceSearch() {
        // 取消之前的搜索任务
        pendingSearchTask?.cancel()
        
        // 如果搜索文本为空，清空结果
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        // 延迟执行搜索（防抖 0.5 秒）
        let task = DispatchWorkItem {
            guard self.isViewActive, self.shouldShowMap else { return }
            self.searchLocation()
        }
        pendingSearchTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }
    
    private func searchLocation() {
        guard !searchText.isEmpty, isViewActive, shouldShowMap else { return }
        
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                guard self.isViewActive, self.shouldShowMap else { return }
                self.isSearching = false
                if let error = error {
                    // 忽略取消错误
                    if let clError = error as? CLError, clError.code != .geocodeCanceled {
                        print("搜索失败: \(error.localizedDescription)")
                    }
                    return
                }
                if let response = response {
                    self.searchResults = response.mapItems
                }
            }
        }
    }
    
    private func selectLocation(item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        isUpdatingLocation = true
        region.center = coordinate
        selectedLocation = coordinate
        locationName = item.name ?? ""
        locationAddress = formatAddress(from: item.placemark) ?? item.name ?? ""
        searchResults = []
        searchText = ""
        isUpdatingLocation = false
    }
    
    @MainActor
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        // 取消之前的反向地理编码
        currentGeocoder?.cancelGeocode()
        
        guard isViewActive, shouldShowMap else { return }
        
        let geocoder = CLGeocoder()
        currentGeocoder = geocoder
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            // 检查视图是否仍然活跃
            guard self.isViewActive, self.shouldShowMap else { return }
            
            DispatchQueue.main.async {
                guard self.isViewActive, self.shouldShowMap else { return }
                
                if let error = error {
                    // 忽略取消错误和网络错误（这些是正常的）
                    if let clError = error as? CLError {
                        switch clError.code {
                        case .geocodeCanceled, .network:
                            // 这些错误可以忽略
                            break
                        default:
                            // 只在调试模式下打印其他错误
                            #if DEBUG
                            print("反向地理编码失败: \(error.localizedDescription)")
                            #endif
                        }
                    } else {
                        #if DEBUG
                        print("反向地理编码失败: \(error.localizedDescription)")
                        #endif
                    }
                    return
                }
                
                guard self.isViewActive, self.shouldShowMap else { return }
                
                if let placemark = placemarks?.first {
                    // 使用统一的地址格式化方法
                    self.locationName = placemark.name ?? ""
                    self.locationAddress = self.formatAddress(from: placemark) ?? placemark.name ?? "未知地点"
                }
            }
        }
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String? {
        // 使用 CNPostalAddressFormatter 来格式化地址，更安全精准
        if let postalAddress = placemark.postalAddress {
            return CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
        }
        // 如果没有 postalAddress，返回 name
        return placemark.name
    }
    
    /// 清理资源并关闭视图
    private func cleanupAndDismiss() {
        cleanupResources()
        dismiss()
    }
    
    /// 清理所有进行中的异步操作
    private func cleanupResources() {
        // 先隐藏 Map，防止在清理过程中继续渲染
        shouldShowMap = false
        
        // 标记视图为非活跃状态
        isViewActive = false
        
        // 取消延迟更新任务
        pendingUpdateTask?.cancel()
        pendingUpdateTask = nil
        
        // 取消搜索任务
        pendingSearchTask?.cancel()
        pendingSearchTask = nil
        
        // 取消反向地理编码
        currentGeocoder?.cancelGeocode()
        currentGeocoder = nil
        
        // 停止位置更新
        locationManager.stopUpdatingLocation()
        
        // 清空搜索相关状态
        searchResults = []
        searchText = ""
    }
}

// MARK: - 位置管理器（参考苹果地图和高德地图的GPS定位方式）
class LocationPickerManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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
    
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
}
