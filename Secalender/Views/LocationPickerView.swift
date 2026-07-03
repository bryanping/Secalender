//
//  LocationPickerView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import CoreLocation
import Contacts
import GoogleMaps
import GooglePlaces
#if canImport(UIKit)
import UIKit
#endif

struct LocationPickerView: View {
    @Binding var selectedAddress: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) var dismiss
    
    @State private var region: CLLocationCoordinate2D = {
        // 从本地缓存加载最后一次GPS位置作为初始值
        if let lastCoordinate = LocationCacheManager.shared.loadLastLocation() {
            return lastCoordinate
        }
        // 如果没有缓存，使用默认值（稍后会被GPS更新）
        return CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }()
    @State private var cameraPosition: GMSCameraPosition?
    @State private var isLocating = true
    @State private var locationError: String?
    @State private var searchText = ""
    @State private var searchResults: [GooglePlaceResult] = []
    @State private var isSearching = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""
    @State private var locationAddress = ""
    @StateObject private var locationManager = LocationPickerManager()
    
    // Google Places Autocomplete 相关状态
    @StateObject private var searchCompleter = GooglePlacesAutocompleteManager()
    @State private var showSearchResults = false // 是否显示正式搜索结果（而非建议）
    
    
    // 重构后的状态管理：简化状态变量
    @State private var reverseGeocodeTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?
    @State private var locationTask: Task<Void, Never>?
    
    // 搜索选择后短暂冻结地图反查（1秒）
    @State private var freezeReverseGeocodeUntil: Date?
    
    // 记录上一次的坐标，用于比较变化
    @State private var lastRegionCenter: CLLocationCoordinate2D?
    
    // Google Places Manager
    private let placesManager = GooglePlacesManager.shared
    
    @FocusState private var isSearchFieldFocused: Bool
    
    // 计算属性：是否应该隐藏地图（当搜索栏有焦点或有搜索信息时隐藏）
    private var shouldHideMap: Bool {
        isSearchFieldFocused || (!searchText.isEmpty && (showSearchResults ? (!searchResults.isEmpty || isSearching) : !searchCompleter.completions.isEmpty))
    }
    
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
                                Text("location_picker.searching".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            } else if !searchResults.isEmpty {
                                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                            Button(action: {
                                selectLocation(item: item)
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                            if !item.address.isEmpty {
                                                Text(item.address.formattedForDisplay)
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
                                    Text("location_picker.no_results".localized())
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            // 显示搜索建议
                            ForEach(searchCompleter.completions) { completion in
                                Button(action: {
                                    selectCompletion(completion)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(completion.primaryText)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            if !completion.secondaryText.isEmpty {
                                                Text(completion.secondaryText.formattedForDisplay)
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
                if !shouldHideMap {
                ZStack {
                        // Google Maps 视图
                        GoogleMapView(
                            region: $region,
                            cameraPosition: $cameraPosition,
                            onCameraChange: { coordinate in
                                // 用户拖动地图后，清除 cameraPosition，让地图跟随用户操作
                                // 这样可以避免地图被持续重置到之前设置的位置
                                if cameraPosition != nil {
                                    cameraPosition = nil
                                }
                                
                                handleRegionChange()
                                // 滑动地图时收起键盘
                                if isSearchFieldFocused {
                                    isSearchFieldFocused = false
                                    hideKeyboard()
                                }
                            }
                        )
                    
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
                                .background(Color(.systemBackground).opacity(0.9))
                            .cornerRadius(10)
                    } else if let error = locationError {
                        VStack(spacing: 8) {
                            Image(systemName: "location.slash")
                                .font(.title2)
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                    .foregroundColor(.primary)
                            Button("重试") {
                                locationTask = Task {
                                    await requestLocationAndUpdate()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                            .background(Color(.systemBackground).opacity(0.9))
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
                // 与地图使用相同的隐藏条件
                if !shouldHideMap {
                VStack(spacing: 12) {
                    // 统一显示格式：地点名称 + 地点地址
                    if !locationName.isEmpty || !locationAddress.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            // 显示组合后的地址（名称 + 地址）
                            Text(formatAddressForDisplay(name: locationName, address: locationAddress))
                                .font(.headline)
                                .foregroundColor(.primary)
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
                            // 格式化地址显示：名字＋地址（移除邮政编码）
                            if !locationName.isEmpty || !locationAddress.isEmpty {
                                selectedAddress = formatAddressForDisplay(name: locationName, address: locationAddress)
                            } else if let coordinate = selectedLocation {
                                // 使用指示地址替代经纬度
                                selectedAddress = getIndicativeAddress(for: coordinate)
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
            region = coordinate
            cameraPosition = GMSCameraPosition.camera(
                withLatitude: coordinate.latitude,
                longitude: coordinate.longitude,
                zoom: 15.0
            )
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
            region = coordinate
            cameraPosition = GMSCameraPosition.camera(
                withLatitude: coordinate.latitude,
                longitude: coordinate.longitude,
                zoom: 15.0
            )
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
                region = cachedCoordinate
                cameraPosition = GMSCameraPosition.camera(
                    withLatitude: cachedCoordinate.latitude,
                    longitude: cachedCoordinate.longitude,
                    zoom: 15.0
                )
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
        let newValue = region
        
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
                let currentCenter = region
                let distance = CLLocation(latitude: newValue.latitude, longitude: newValue.longitude)
                    .distance(from: CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude))
                
                // 如果移动超过 5 米，执行反查
                if distance > 5 {
                    selectedLocation = currentCenter
                    lastRegionCenter = currentCenter
                    reverseGeocodeTask?.cancel()
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
        
        // 取消之前的反查任务（立即终止旧请求，避免乱序回写）
        reverseGeocodeTask?.cancel()
        
        // 创建新的防抖任务（确保在 MainActor 上）
        reverseGeocodeTask = Task { @MainActor in
            // 等待 0.5 秒防抖
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // 检查是否已取消
            if Task.isCancelled { return }
            
            await reverseGeocode(coordinate: newValue)
        }
    }
    
    /// 生成指示地址（当无法获取详细地址时使用，替代经纬度显示）
    private func getIndicativeAddress(for coordinate: CLLocationCoordinate2D) -> String {
        return "未知位置"
    }
    
    /// 格式化地址显示（名字＋地址，移除邮政编码和国家字样）
    /// 参考：https://developers.google.com/maps/documentation/ios-sdk
    private func formatAddressForDisplay(name: String, address: String) -> String {
        // 清理和验证输入
        let cleanedName = name.formattedForDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAddress = address.formattedForDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 验证地址有效性
        let isValidName = AddressFormatter.isValidAddress(cleanedName)
        let isValidAddress = AddressFormatter.isValidAddress(cleanedAddress)
        
        // 如果名称和地址都无效，返回默认值
        if !isValidName && !isValidAddress {
            return "未知位置"
        }
        
        // 如果只有名称有效
        if isValidName && !isValidAddress {
            return cleanedName
        }
        
        // 如果只有地址有效
        if !isValidName && isValidAddress {
            return cleanedAddress
        }
        
        // 如果名称和地址都有效，智能组合
        // 检查名称是否已经包含在地址中（避免重复）
        if cleanedAddress.localizedCaseInsensitiveContains(cleanedName) {
            return cleanedAddress
        }
        
        // 检查地址是否已经包含在名称中
        if cleanedName.localizedCaseInsensitiveContains(cleanedAddress) {
            return cleanedName
        }
        
        // 根据地址格式决定分隔符
        // 中文地址通常不需要分隔符，英文地址用空格或逗号
        let separator: String
        if cleanedAddress.range(of: #"[\u4e00-\u9fff]"#, options: .regularExpression) != nil {
            // 包含中文字符，使用空字符串或空格
            separator = cleanedName.isEmpty ? "" : " "
        } else {
            // 英文地址，使用空格
            separator = " "
        }
        
        return "\(cleanedName)\(separator)\(cleanedAddress)".trimmingCharacters(in: .whitespacesAndNewlines)
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
    private func selectCompletion(_ completion: GooglePlaceAutocomplete) {
        // 收起键盘
        isSearchFieldFocused = false
        hideKeyboard()
        
        // 更新搜索文本为建议的标题
        searchText = completion.primaryText
        
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
    private func searchLocationWithCompletion(_ completion: GooglePlaceAutocomplete) async {
        isSearching = true
        defer { isSearching = false }
        
        // 使用 Google Places API 获取地点详细信息
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            searchCompleter.fetchPlaceDetails(placeID: completion.placeID) { result in
                Task { @MainActor in
                    if Task.isCancelled {
                        searchResults = []
                        continuation.resume()
                        return
                    }
                    
                    switch result {
                    case .success(let place):
                        searchResults = [place]
                        // 自动选择位置，恢复地图并聚焦到该位置
                        selectLocation(item: place)
                    case .failure(let error):
                        print("搜索失败: \(error.localizedDescription)")
                        searchResults = []
                    }
                    continuation.resume()
                }
            }
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
        
        // 使用 Google Places API 搜索（现在只返回 predictions，不获取详细信息）
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            placesManager.searchPlaces(query: query, coordinate: region) { result in
                Task { @MainActor in
                    if Task.isCancelled {
                        searchResults = []
                        continuation.resume()
                        return
                    }
                    
                    switch result {
                    case .success(let places):
                        // 现在 searchPlaces 只返回 predictions，需要获取详细信息
                        let placeIDs = places.map { $0.placeID }
                        placesManager.fetchPlaceDetails(placeIDs: placeIDs) { detailsResult in
                            Task { @MainActor in
                                if Task.isCancelled {
                                    searchResults = []
                                    continuation.resume()
                                    return
                                }
                                
                                switch detailsResult {
                                case .success(let detailedPlaces):
                                    searchResults = detailedPlaces
                                case .failure(let error):
                                    #if DEBUG
                                    print("获取地点详情失败: \(error.localizedDescription)")
                                    #endif
                                    // 即使获取详情失败，也显示 predictions 结果
                                    searchResults = places
                                }
                                continuation.resume()
                            }
                        }
                    case .failure(let error):
                        #if DEBUG
                        print("搜索失败: \(error.localizedDescription)")
                        #endif
                        searchResults = []
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    @MainActor
    private func selectLocation(item: GooglePlaceResult) {
        // 如果坐标无效（临时坐标），需要获取详细信息
        let needsFetchDetails = item.coordinate.latitude == 0 && item.coordinate.longitude == 0
        
        if needsFetchDetails {
            // 获取地点详细信息
            placesManager.fetchPlaceDetails(placeIDs: [item.placeID]) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let places):
                        if let place = places.first {
                            self.applySelectedLocation(place)
                        } else {
                            // 如果获取失败，使用现有信息
                            self.applySelectedLocation(item)
                        }
                    case .failure:
                        // 如果获取失败，使用现有信息
                        self.applySelectedLocation(item)
                    }
                }
            }
        } else {
            // 已有完整信息，直接应用
            applySelectedLocation(item)
        }
    }
    
    /// 应用选中的位置（内部辅助方法）
    @MainActor
    private func applySelectedLocation(_ item: GooglePlaceResult) {
        let coordinate = item.coordinate
        
        // 取消正在进行的反查任务
        reverseGeocodeTask?.cancel()
        
        // 设置区域（这会触发 handleRegionChange，但会被冻结期阻止）
        region = coordinate
        cameraPosition = GMSCameraPosition.camera(
            withLatitude: coordinate.latitude,
            longitude: coordinate.longitude,
            zoom: 15.0
        )
        selectedLocation = coordinate
        
        // 智能处理地点名称和地址
        let cleanedName = item.name.formattedForDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAddress = item.address.formattedForDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 验证并设置地点名称
        if AddressFormatter.isValidAddress(cleanedName) && 
           !cleanedName.localizedCaseInsensitiveContains("Dropped Pin") &&
           !cleanedName.localizedCaseInsensitiveContains("未知") {
            locationName = cleanedName
        } else {
            locationName = ""
        }
        
        // 验证并设置地址
        if AddressFormatter.isValidAddress(cleanedAddress) {
            locationAddress = cleanedAddress
        } else {
            // 如果地址无效，尝试使用指示地址
            let indicativeAddress = getIndicativeAddress(for: coordinate)
            if AddressFormatter.isValidAddress(indicativeAddress) {
                locationAddress = indicativeAddress.formattedForDisplay
            } else {
                locationAddress = ""
            }
        }
        
        // 如果名称和地址相同，清空名称避免重复显示
        if locationName == locationAddress {
            locationName = ""
        }
        
        // 如果名称包含在地址中，从地址中移除名称部分
        if !locationName.isEmpty && locationAddress.contains(locationName) {
            locationAddress = locationAddress.replacingOccurrences(of: locationName, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
        }
        
        // 清空搜索结果列表和搜索建议，恢复地图显示
        searchResults = []
        showSearchResults = false
        searchCompleter.updateQueryFragment("") // 清空搜索建议
        searchText = "" // 清空搜索文本，确保地图恢复显示
        
        // 收起键盘
        isSearchFieldFocused = false
        hideKeyboard()
        
        // 清除错误状态（如果用户通过搜索选择了位置，清除之前的定位错误）
        locationError = nil
        
        // 冻结地图反查 1 秒（防止搜索选择后被反查覆盖）
        freezeReverseGeocodeUntil = Date().addingTimeInterval(1.0)
    }
    
    /// 反向地理编码（使用 Google Places API）
    @MainActor
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async {
        // 检查是否在冻结期内
        if let freezeUntil = freezeReverseGeocodeUntil, Date() < freezeUntil {
            return
        }
        
        // 取消之前的反查任务
        reverseGeocodeTask?.cancel()
        
        // 使用 Google Places API 进行反向地理编码
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            placesManager.reverseGeocode(coordinate: coordinate) { result in
                Task { @MainActor in
                    if Task.isCancelled {
                        continuation.resume()
                        return
                    }
            
                    switch result {
                    case .success(let place):
                        if let place = place {
                            // 清理和验证地点名称
                            let cleanedName = place.name.formattedForDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
                            let cleanedAddress = place.address.formattedForDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // 验证名称有效性
                            let isValidName = AddressFormatter.isValidAddress(cleanedName) &&
                                            !cleanedName.localizedCaseInsensitiveContains("Dropped Pin") &&
                                            !cleanedName.localizedCaseInsensitiveContains("未知")
                            
                            // 验证地址有效性
                            let isValidAddress = AddressFormatter.isValidAddress(cleanedAddress)
                            
                            if isValidName && isValidAddress {
                                // 名称和地址都有效
                                locationName = cleanedName
                                locationAddress = cleanedAddress
                                
                                // 如果名称和地址相同，清空名称
                                if locationName == locationAddress {
                                    locationName = ""
                                }
                                
                                // 如果名称包含在地址中，从地址中移除名称
                                if !locationName.isEmpty && locationAddress.contains(locationName) {
                                    locationAddress = locationAddress.replacingOccurrences(of: locationName, with: "")
                                        .trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
                                }
                            } else if isValidName && !isValidAddress {
                                // 只有名称有效
                                locationName = cleanedName
                                locationAddress = ""
                            } else if !isValidName && isValidAddress {
                                // 只有地址有效，尝试从地址中提取名称
                                // 根据地址格式智能分割
                                let separators = CharacterSet(charactersIn: "，, ")
                                let addressParts = cleanedAddress.components(separatedBy: separators).filter { !$0.isEmpty }
                                
                                if addressParts.count > 1 {
                                    // 多个部分：第一部分作为名称，剩余作为地址
                                    locationName = addressParts.first ?? ""
                                    locationAddress = addressParts.dropFirst().joined(separator: " ")
                                } else {
                                    // 单个部分：全部作为名称
                                    locationName = cleanedAddress
                                    locationAddress = ""
                                }
                            } else {
                                // 都无效，使用指示地址
                                let indicativeAddress = getIndicativeAddress(for: coordinate)
                                if AddressFormatter.isValidAddress(indicativeAddress) {
                                    locationName = indicativeAddress.formattedForDisplay
                                    locationAddress = ""
                                } else {
                                    locationName = ""
                                    locationAddress = ""
                                }
                            }
                        } else {
                            // 如果没有结果，使用指示地址作为 fallback
                            let indicativeAddress = getIndicativeAddress(for: coordinate)
                            if AddressFormatter.isValidAddress(indicativeAddress) {
                                locationName = indicativeAddress.formattedForDisplay
                                locationAddress = ""
                            } else {
                                locationName = ""
                                locationAddress = ""
                            }
                        }
                    case .failure(let error):
                        // 错误时使用指示地址作为 fallback
                        let indicativeAddress = getIndicativeAddress(for: coordinate)
                        if AddressFormatter.isValidAddress(indicativeAddress) {
                            locationName = indicativeAddress.formattedForDisplay
                            locationAddress = ""
                        } else {
                            locationName = ""
                            locationAddress = ""
                        }
                        #if DEBUG
                        print("反向地理编码失败: \(error.localizedDescription)")
                        #endif
                }
                    
                    continuation.resume()
                }
            }
        }
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

