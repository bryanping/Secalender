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
    
    // MKLocalSearchCompleter 相关状态
    @StateObject private var searchCompleter = SearchCompleterManager()
    @State private var showSearchResults = false // 是否显示正式搜索结果（而非建议）
    
    // 附近推荐地点（拖动地图后显示）
    @State private var nearbyPOIs: [MKMapItem] = []
    @State private var isLoadingNearbyPOIs = false
    @State private var nearbyPOITask: Task<Void, Never>?
    
    // 重构后的状态管理：简化状态变量
    @State private var reverseGeocodeTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?
    @State private var locationTask: Task<Void, Never>?
    
    // 搜索选择后短暂冻结地图反查（1秒）
    @State private var freezeReverseGeocodeUntil: Date?
    
    // 记录上一次的坐标，用于比较变化
    @State private var lastRegionCenter: CLLocationCoordinate2D?
    
    // 统一的地理编码器实例（用于 cancel）
    @State private var geocoder = CLGeocoder()
    
    @FocusState private var isSearchFieldFocused: Bool
    
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
                            // 按回车时收起键盘
                            isSearchFieldFocused = false
                            hideKeyboard()
                            // 如果有建议，选择第一个建议；否则进行正式搜索
                            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !query.isEmpty else {
                                searchResults = []
                                showSearchResults = false
                                return
                            }
                            
                            if let firstCompletion = searchCompleter.completions.first {
                                // 选择第一个建议
                                selectCompletion(firstCompletion)
                            } else {
                                // 没有建议，进行正式搜索
                                locationError = nil
                                searchTask?.cancel()
                                showSearchResults = true
                                searchTask = Task {
                                    await searchLocation(query: query)
                                }
                            }
                        }
                        .onChange(of: searchText) { oldValue, newValue in
                            // 清除错误状态（用户输入时）
                            if !newValue.isEmpty {
                                locationError = nil
                            }
                            // 使用 completer 提供自动建议
                            updateSearchCompletions(query: newValue)
                        }
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                            showSearchResults = false
                            searchCompleter.updateQueryFragment("")
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                // 搜索建议/结果列表（输入时显示，占据剩余空间）
                if isSearchFieldFocused || (!searchText.isEmpty && (showSearchResults ? (isSearching || !searchResults.isEmpty) : !searchCompleter.completions.isEmpty)) {
                    List {
                        if showSearchResults {
                            // 显示正式搜索结果
                            if isSearching {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                    Text("搜索中...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            } else if !searchResults.isEmpty {
                                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
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
                            } else {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.secondary)
                                    Text("未找到相关地点")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // 显示搜索建议
                            ForEach(Array(searchCompleter.completions.enumerated()), id: \.offset) { index, completion in
                                Button(action: {
                                    selectCompletion(completion)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(completion.title)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            if !completion.subtitle.isEmpty {
                                                Text(completion.subtitle)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: isSearchFieldFocused ? .infinity : 200)
                    .scrollDismissesKeyboard(.interactively)  // 滑动时收起键盘
                }
                
                // 地图视图（搜索时隐藏）
                if !isSearchFieldFocused {
                    ZStack {
                        // 地图视图（始终显示）
                        Map(coordinateRegion: $region,
                            interactionModes: [.pan, .zoom],
                            showsUserLocation: true,
                            userTrackingMode: .none)
                        .onChange(of: EquatableCoordinate(region.center)) { _, _ in
                            handleRegionChange()
                            // 滑动地图时收起键盘
                            if isSearchFieldFocused {
                                isSearchFieldFocused = false
                                hideKeyboard()
                            }
                        }
                        
                        // 中心标记
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                            .offset(y: -20)
                            .allowsHitTesting(false)
                        
                        // 定位状态覆盖层
                        if isLocating {
                            ProgressView("正在定位...")
                                .padding()
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(10)
                        } else if let error = locationError {
                            VStack(spacing: 8) {
                                Image(systemName: "location.slash")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("重试") {
                                    locationTask = Task {
                                        await requestLocationAndUpdate()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                        }
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            // 点击空白区域时收起键盘
                            isSearchFieldFocused = false
                            hideKeyboard()
                        }
                    )
                }
                
                // 底部按钮（搜索时隐藏）
                if !isSearchFieldFocused {
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
                    
                    // 附近推荐地址列表（类似高德地图）
                    if !showSearchResults && !nearbyPOIs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("附近推荐")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(nearbyPOIs.enumerated()), id: \.offset) { index, item in
                                        Button(action: {
                                            selectLocation(item: item)
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.name ?? "未知地点")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                if let address = formatAddress(from: item.placemark) {
                                                    Text(address)
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else if isLoadingNearbyPOIs && !showSearchResults {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("正在加载附近地点...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                    
                    HStack(spacing: 16) {
                        Button("取消") {
                            cleanupAndDismiss()
                        }
                        .foregroundColor(.secondary)
                        
                        Button("确认") {
                            // 如果有地址，使用地址；否则使用坐标
                            if !locationAddress.isEmpty {
                                selectedAddress = locationAddress
                            } else if let coordinate = selectedLocation {
                                // 使用坐标作为地址（格式：纬度,经度）
                                selectedAddress = "\(coordinate.latitude), \(coordinate.longitude)"
                            }
                            selectedCoordinate = selectedLocation
                            cleanupAndDismiss()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedLocation == nil ? Color.gray : Color.blue)
                        .cornerRadius(10)
                        .disabled(selectedLocation == nil)
                    }
                }
                .padding()
            }
            
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                // 请求位置权限并获取实时GPS位置
                locationTask = Task {
                    await requestLocationAndUpdate()
                }
            }
            .onDisappear {
                // 视图消失时只取消任务，不控制 Map 渲染
                isSearchFieldFocused = false
                cleanupResources()
            }
        }
    }
    
    /// 请求位置权限并获取实时GPS位置（重构：移除轮询，使用 await）
    @MainActor
    private func requestLocationAndUpdate() async {
        // 检查是否已取消
        if Task.isCancelled { return }
        
        isLocating = true
        locationError = nil
        
        // 如果有已选择的坐标，使用它
        if let coordinate = selectedCoordinate {
            // 设置短暂的冻结期，避免与 onChange 冲突
            freezeReverseGeocodeUntil = Date().addingTimeInterval(0.5)
            region.center = coordinate
            selectedLocation = coordinate
            lastRegionCenter = coordinate // 设置初始值，避免第一次拖动时立即触发
            await reverseGeocode(coordinate: coordinate)
            isLocating = false
            return
        }
        
        // 请求位置权限
        locationManager.requestPermission()
        
        // 使用 await 等待位置更新（不再轮询）
        let location = await locationManager.nextLocation(timeout: 5.0)
        
        // 检查是否已取消
        if Task.isCancelled { return }
        
        if let currentLocation = location {
            let coordinate = currentLocation.coordinate
            // 保存到本地缓存
            LocationCacheManager.shared.saveLastLocation(currentLocation)
            
            // 设置短暂的冻结期，避免与 onChange 冲突
            freezeReverseGeocodeUntil = Date().addingTimeInterval(0.5)
            region.center = coordinate
            selectedLocation = coordinate
            lastRegionCenter = coordinate // 设置初始值，避免第一次拖动时立即触发
            await reverseGeocode(coordinate: coordinate)
            isLocating = false
        } else {
            // 定位失败，尝试使用缓存的位置
            if let cachedCoordinate = LocationCacheManager.shared.loadLastLocation() {
                print("📍 使用缓存的GPS位置")
                // 设置短暂的冻结期，避免与 onChange 冲突
                freezeReverseGeocodeUntil = Date().addingTimeInterval(0.5)
                region.center = cachedCoordinate
                selectedLocation = cachedCoordinate
                lastRegionCenter = cachedCoordinate // 设置初始值，避免第一次拖动时立即触发
                await reverseGeocode(coordinate: cachedCoordinate)
                isLocating = false
            } else {
                // 定位失败且无缓存，显示错误提示
                locationError = "无法获取当前位置，请检查定位权限设置"
                isLocating = false
                print("⚠️ GPS定位失败，无法获取当前位置")
            }
        }
    }
    
    /// 处理地图区域变化（统一入口）
    @MainActor
    private func handleRegionChange() {
        let newValue = region.center
        
        // ⛳️ 若還在冷卻期，直接跳過，避免建立 Task 再被取消
        if let freezeUntil = freezeReverseGeocodeUntil, Date() < freezeUntil {
        return
        }
        // 清除错误状态（用户拖动地图时）
        locationError = nil
        
        // 检查是否在冻结期内（搜索选择后1秒内不触发反查）
        if let freezeUntil = freezeReverseGeocodeUntil, Date() < freezeUntil {
            lastRegionCenter = newValue
            // 如果仍在冻结期，记下中心点，延后触发反查
            Task { @MainActor in
                let delay = freezeUntil.timeIntervalSinceNow
                guard delay > 0 else { return }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                // 再次确认是否取消
                if Task.isCancelled { return }
                searchResults = []
                // 检查地图是否在冻结期间移动了
                let currentCenter = region.center
                let distance = CLLocation(latitude: newValue.latitude, longitude: newValue.longitude)
                    .distance(from: CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude))
                
                // 如果移动超过 5 米，执行反查
                if distance > 5 {
                    selectedLocation = currentCenter
                    lastRegionCenter = currentCenter
                    reverseGeocodeTask?.cancel()
                    geocoder.cancelGeocode()
                    reverseGeocodeTask = Task { @MainActor in
                        await reverseGeocode(coordinate: currentCenter)
                    }
                }
            }
            return
        }
        
        // 检查坐标变化是否足够大（约 10 米）
        if let oldValue = lastRegionCenter {
            let distance = CLLocation(latitude: oldValue.latitude, longitude: oldValue.longitude)
                .distance(from: CLLocation(latitude: newValue.latitude, longitude: newValue.longitude))
            guard distance > 10 else { return } // 10米阈值
        }
        
        // 更新记录
        lastRegionCenter = newValue
        selectedLocation = newValue
        
        // 取消之前的反查任务和 geocoder（立即终止旧请求，避免乱序回写）
        reverseGeocodeTask?.cancel()
        geocoder.cancelGeocode()
        
        // 创建新的防抖任务（确保在 MainActor 上）
        reverseGeocodeTask = Task { @MainActor in
            // 等待 0.5 秒防抖
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // 检查是否已取消
            if Task.isCancelled { return }
            
            await reverseGeocode(coordinate: newValue)
        }
    }
    
    /// 更新搜索建议（使用 MKLocalSearchCompleter）
    private func updateSearchCompletions(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchCompleter.updateQueryFragment(trimmedQuery)
            showSearchResults = false
            return
        }
        
        // 更新 completer 的查询片段
        searchCompleter.updateQueryFragment(trimmedQuery)
        searchCompleter.region = region
        showSearchResults = false // 显示建议而非搜索结果
    }
    
    /// 选择搜索建议，进行正式搜索
    @MainActor
    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        // 收起键盘
        isSearchFieldFocused = false
        hideKeyboard()
        
        // 更新搜索文本为建议的标题
        searchText = completion.title
        
        // 切换到显示搜索结果模式
        showSearchResults = true
        
        // 取消之前的搜索任务
        searchTask?.cancel()
        
        // 使用建议进行正式搜索
        searchTask = Task {
            await searchLocationWithCompletion(completion)
        }
    }
    
    /// 使用搜索建议进行正式搜索
    @MainActor
    private func searchLocationWithCompletion(_ completion: MKLocalSearchCompletion) async {
        isSearching = true
        defer { isSearching = false }
        
        let request = MKLocalSearch.Request(completion: completion)
        request.region = region
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            // 检查是否已取消
            if Task.isCancelled {
                searchResults = []
                return
            }
            searchResults = response.mapItems
        } catch {
            // 检查是否已取消
            if Task.isCancelled {
                searchResults = []
                return
            }
            // 记录错误
            if let mkError = error as? MKError {
                print("搜索失败: \(mkError.localizedDescription)")
            } else {
                print("搜索失败: \(error.localizedDescription)")
            }
            searchResults = []
        }
    }
    
    /// 搜索防抖处理（使用 Task 替代 DispatchWorkItem）
    private func debounceSearch() {
        // 取消之前的搜索任务
        searchTask?.cancel()
        
        // 快照搜索文本（避免在防抖期间 searchText 变化）
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果搜索文本为空，清空结果
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // 创建新的防抖任务
        searchTask = Task {
            // 等待 0.5 秒防抖
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // 检查是否已取消
            if Task.isCancelled { return }
            
            await searchLocation(query: query)
        }
    }
    
    @MainActor
    private func searchLocation(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false } // 确保无论是否被 cancel 都会重置状态
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            // 检查是否已取消
            if Task.isCancelled { 
                searchResults = []
                return 
            }
            searchResults = response.mapItems
        } catch {
            // 检查是否已取消
            if Task.isCancelled {
                searchResults = []
                return
            }
            // 忽略取消错误，但记录其他错误
            if let mkError = error as? MKError {
                print("搜索失败: \(mkError.localizedDescription)")
            } else {
                print("搜索失败: \(error.localizedDescription)")
            }
            // 搜索失败时清空结果
            searchResults = []
        }
    }
    
    @MainActor
    private func selectLocation(item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        
        // 取消正在进行的反查任务
        reverseGeocodeTask?.cancel()
        geocoder.cancelGeocode()
        
        // 设置区域（这会触发 handleRegionChange，但会被冻结期阻止）
        region.center = coordinate
        selectedLocation = coordinate
        
        // 直接设置地址信息（保持搜索结果的名称，确保地址不为空）
        locationName = item.name ?? "未知地点"
        locationAddress = formatAddress(from: item.placemark) ?? item.name ?? "\(coordinate.latitude), \(coordinate.longitude)"
        
        // 清空搜索结果列表，但保留搜索框文字（类似高德地图行为）
        searchResults = []
        showSearchResults = false
        
        // 收起键盘
        isSearchFieldFocused = false
        hideKeyboard()
        
        // 获取新位置附近的POI推荐
        Task {
            await loadNearbyPOIs(coordinate: coordinate)
        }
        
        // 清除错误状态（如果用户通过搜索选择了位置，清除之前的定位错误）
        locationError = nil
        
        // 冻结地图反查 1 秒（防止搜索选择后被反查覆盖）
        freezeReverseGeocodeUntil = Date().addingTimeInterval(1.0)
    }
    
    /// 反向地理编码（重构：使用统一的 geocoder 实例，支持 cancel）
    @MainActor
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async {
        // 检查是否在冻结期内
        if let freezeUntil = freezeReverseGeocodeUntil, Date() < freezeUntil {
            return
        }
        
        // 取消之前的反查（但不清空地址，保持上一次地址显示）
        geocoder.cancelGeocode()
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            // 检查是否已取消
            if Task.isCancelled { return }
            
            // 只有成功拿到新 placemark 才更新地址（确保地址不为空）
            if let placemark = placemarks.first {
                // 使用统一的地址格式化方法
                locationName = placemark.name ?? "Dropped Pin"
                locationAddress = formatAddress(from: placemark) ?? placemark.name ?? "\(coordinate.latitude), \(coordinate.longitude)"
            } else {
                // 如果没有 placemark，使用坐标作为 fallback
                locationName = "Dropped Pin"
                locationAddress = "\(coordinate.latitude), \(coordinate.longitude)"
            }
        } catch {
            // 检查是否已取消
            if Task.isCancelled { return }
            
            // 对于取消和网络错误，使用坐标作为 fallback（确保地址不为空）
            if let clError = error as? CLError {
                switch clError.code {
                case .geocodeCanceled:
                    // 取消时保持上一次地址（不清空）
                    break
                case .network:
                    // 网络错误时使用坐标作为 fallback
                    locationName = "Dropped Pin"
                    locationAddress = "\(coordinate.latitude), \(coordinate.longitude)"
                default:
                    // 其他错误也使用坐标作为 fallback
                    locationName = "Dropped Pin"
                    locationAddress = "\(coordinate.latitude), \(coordinate.longitude)"
                    #if DEBUG
                    print("反向地理编码失败: \(error.localizedDescription)")
                    #endif
                }
            } else {
                // 未知错误，使用坐标作为 fallback
                locationName = "Dropped Pin"
                locationAddress = "\(coordinate.latitude), \(coordinate.longitude)"
                #if DEBUG
                print("反向地理编码失败: \(error.localizedDescription)")
                #endif
            }
        }
        
        // 反查成功后，获取附近POI推荐（类似高德地图）
        Task {
            await loadNearbyPOIs(coordinate: coordinate)
        }
    }
    
    /// 加载附近POI推荐（拖动地图后显示）
    @MainActor
    private func loadNearbyPOIs(coordinate: CLLocationCoordinate2D) async {
        // 取消之前的任务
        nearbyPOITask?.cancel()
        
        // 如果正在显示搜索结果，不显示附近推荐
        if showSearchResults && !searchResults.isEmpty {
            nearbyPOIs = []
            return
        }
        
        isLoadingNearbyPOIs = true
        
        nearbyPOITask = Task { @MainActor in
            // 使用当前地址名称搜索附近POI（更准确）
            var searchQuery = locationName
            if searchQuery.isEmpty || searchQuery == "Dropped Pin" {
                // 如果没有地址名称，使用地址
                searchQuery = locationAddress
            }
            
            // 如果仍然为空，使用通用搜索
            if searchQuery.isEmpty || searchQuery.contains(",") {
                searchQuery = "附近"
            }
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchQuery
            request.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // 约1公里范围
            )
            
            let search = MKLocalSearch(request: request)
            
            do {
                let response = try await search.start()
                
                // 检查是否已取消
                if Task.isCancelled {
                    isLoadingNearbyPOIs = false
                    return
                }
                
                // 过滤并排序结果（排除当前点，优先显示名称和地址都有的POI）
                let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let sortedItems = response.mapItems
                    .filter { item in
                        guard let name = item.name, !name.isEmpty else { return false }
                        // 排除距离太近的点（可能是同一个地点）
                        let itemLocation = CLLocation(
                            latitude: item.placemark.coordinate.latitude,
                            longitude: item.placemark.coordinate.longitude
                        )
                        let distance = currentLocation.distance(from: itemLocation)
                        return distance > 50 // 至少50米外的点
                    }
                    .sorted { item1, item2 in
                        // 按距离排序
                        let loc1 = CLLocation(
                            latitude: item1.placemark.coordinate.latitude,
                            longitude: item1.placemark.coordinate.longitude
                        )
                        let loc2 = CLLocation(
                            latitude: item2.placemark.coordinate.latitude,
                            longitude: item2.placemark.coordinate.longitude
                        )
                        return currentLocation.distance(from: loc1) < currentLocation.distance(from: loc2)
                    }
                    .prefix(10) // 最多显示10个
                
                nearbyPOIs = Array(sortedItems)
            } catch {
                // 检查是否已取消
                if Task.isCancelled {
                    isLoadingNearbyPOIs = false
                    return
                }
                #if DEBUG
                print("加载附近POI失败: \(error.localizedDescription)")
                #endif
                nearbyPOIs = []
            }
            
            isLoadingNearbyPOIs = false
        }
        
        await nearbyPOITask?.value
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String? {
        // 使用 CNPostalAddressFormatter 来格式化地址，更安全精准
        if let postalAddress = placemark.postalAddress {
            let formatted = CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
            // 转换为单行（移除换行符）
            return formatted.replacingOccurrences(of: "\n", with: " ")
        }
        // 如果没有 postalAddress，返回 name
        return placemark.name
    }
    
    /// 收起键盘
    private func hideKeyboard() {
        isSearchFieldFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    /// 清理资源并关闭视图
    private func cleanupAndDismiss() {
        cleanupResources()
        dismiss()
    }
    
    /// 清理所有进行中的异步操作（重构：只取消任务，不控制 Map 渲染）
    private func cleanupResources() {
        // 取消所有任务
        reverseGeocodeTask?.cancel()
        reverseGeocodeTask = nil
        
        searchTask?.cancel()
        searchTask = nil
        
        locationTask?.cancel()
        locationTask = nil
        
        nearbyPOITask?.cancel()
        nearbyPOITask = nil
        
        // 取消地理编码
        geocoder.cancelGeocode()
        
        // 停止位置更新
        locationManager.stopUpdatingLocation()
        
        // 清空搜索相关状态
        searchResults = []
        searchText = ""
        nearbyPOIs = []
    }
}

// MARK: - EquatableCoordinate（用于统一监听 region.center）
struct EquatableCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    static func == (lhs: EquatableCoordinate, rhs: EquatableCoordinate) -> Bool {
        // 使用约 5 米的精度进行比较（避免微小变化触发，但不要太严格）
        abs(lhs.latitude - rhs.latitude) < 0.00005 && abs(lhs.longitude - rhs.longitude) < 0.00005
    }
}

// MARK: - 位置管理器（参考苹果地图和高德地图的GPS定位方式）
class LocationPickerManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var currentRequestId: UUID? // 用于标识当前请求
    
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
    
    /// 等待下一个位置更新（替代轮询）
    func nextLocation(timeout: TimeInterval) async -> CLLocation? {
        // 如果已有位置，直接返回
        if let location = currentLocation {
            return location
        }
        
        // 如果有 pending continuation，先取消/结束旧的再开新的（防止续体被覆盖）
        if let oldContinuation = locationContinuation {
            oldContinuation.resume(returning: nil)
            locationContinuation = nil
            currentRequestId = nil
        }
        
        // 请求权限并启动位置更新
        requestPermission()
        
        // 生成新的请求 ID
        let requestId = UUID()
        currentRequestId = requestId
        
        // 等待位置更新（使用 continuation）
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                locationContinuation = continuation
                
                // 设置超时任务
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    // 检查是否仍然是当前请求（通过 requestId 比较）
                    if currentRequestId == requestId {
                        locationContinuation?.resume(returning: currentLocation)
                        locationContinuation = nil
                        currentRequestId = nil
                    }
                }
            }
        } onCancel: {
            if currentRequestId == requestId {
                locationContinuation?.resume(returning: nil)
                locationContinuation = nil
                currentRequestId = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        // 验证位置精度（类似苹果地图和高德地图的验证）
        if location.horizontalAccuracy > 0 && location.horizontalAccuracy < 100 {
            // 精度在100米以内，认为是有效位置
            currentLocation = location
            if let continuation = locationContinuation {
                locationContinuation = nil
                continuation.resume(returning: location)
                currentRequestId = nil
            }
        } else if location.horizontalAccuracy > 0 {
            // 精度较差，但可以使用
            currentLocation = location
            if let continuation = locationContinuation {
                locationContinuation = nil
                continuation.resume(returning: location)
                currentRequestId = nil
            }
        }
        
        // 获取到位置后停止更新以节省电量
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置获取失败: \(error.localizedDescription)")
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: nil)
            currentRequestId = nil
        }
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

// MARK: - 搜索建议管理器（使用 MKLocalSearchCompleter）
class SearchCompleterManager: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    
    @Published var completions: [MKLocalSearchCompletion] = []
    
    var region: MKCoordinateRegion? {
        didSet {
            if let region = region {
                completer.region = region
            }
        }
    }
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
        completer.filterType = .locationsAndQueries
    }
    
    func updateQueryFragment(_ fragment: String) {
        completer.queryFragment = fragment
    }
    
    // MARK: - MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        #if DEBUG
        print("搜索建议失败: \(error.localizedDescription)")
        #endif
        DispatchQueue.main.async {
            self.completions = []
        }
    }
}
