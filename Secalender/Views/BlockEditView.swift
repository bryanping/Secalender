//
//  BlockEditView.swift
//  Secalender
//
//  单个 Block 编辑页面（弹窗设计，参考 EventEditView）
//

import SwiftUI
import Foundation
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

struct BlockEditView: View {
    let block: TimeBlock
    let onSave: (TimeBlock) -> Void
    let onCancel: () -> Void
    var plan: PlanResult? = nil  // 完整行程（用于获取后续行程位置）
    var interestTags: [String] = []  // 兴趣偏好标签
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: FirebaseUserManager
    
    @State private var title: String
    @State private var location: String
    @State private var startDate: Date
    @State private var startTime: Date
    @State private var endTime: Date?
    @State private var description: String
    @State private var isAllDay: Bool = false
    @State private var isHasEnd: Bool = true  // 默认有结束时间
    
    // 周边特色选择器相关状态
    @State private var surroundingAttractions: [SurroundingAttraction] = []
    @State private var isLoadingSurroundingFeatures = false
    @State private var selectedAttraction: SurroundingAttraction? = nil
    @State private var previewTitle: String = ""  // 预览标题（选择后更新）
    @State private var previewDescription: String = ""  // 预览描述（选择后更新）
    
    // 分类选择
    @State private var selectedSortType: AttractionSortType = .popularity
    
    // 地图选择器相关状态
    @State private var showLocationPicker = false
    @State private var customLocationAddress: String = ""
    @State private var customLocationCoordinate: CLLocationCoordinate2D? = nil
    @State private var isCustomLocation: Bool = false  // 是否为自定义位置（从地图选择）
    @State private var isEditingCustomLocation: Bool = false  // 是否正在编辑自定义位置的标题和描述
    
    // 地理围栏相关
    @State private var currentBlockCoordinate: CLLocationCoordinate2D? = nil
    @State private var futureRouteLocations: [CLLocation] = []
    private let maxGeofenceDistance: Double = 5000  // 最大距离5公里（米）
    
    init(block: TimeBlock, onSave: @escaping (TimeBlock) -> Void, onCancel: @escaping () -> Void, plan: PlanResult? = nil, interestTags: [String] = []) {
        self.block = block
        self.onSave = onSave
        self.onCancel = onCancel
        self.plan = plan
        self.interestTags = interestTags
        
        let calendar = Calendar.current
        _title = State(initialValue: block.title)
        _location = State(initialValue: block.location ?? "")
        _startDate = State(initialValue: calendar.startOfDay(for: block.startTime))
        _startTime = State(initialValue: block.startTime)
        _endTime = State(initialValue: block.endTime)
        _description = State(initialValue: block.description ?? "")
        _isAllDay = State(initialValue: false)
        _isHasEnd = State(initialValue: true)
        _previewTitle = State(initialValue: block.title)
        _previewDescription = State(initialValue: block.description ?? "")
    }
    
    // MARK: - 排序类型枚举
    enum AttractionSortType: String, CaseIterable {
        case distance = "距離"
        case popularity = "熱門"
        case route = "沿途"
        
        var icon: String {
            switch self {
            case .distance: return "location.fill"
            case .popularity: return "flame.fill"
            case .route: return "map.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 周边特色选择器（最上面）
                    if !location.isEmpty {
                        surroundingAttractionsSelector
                    }
                    
                    // 行程資訊卡片（参考 EventEditView）
                    EventFormCard(icon: "calendar", title: "行程資訊", iconColor: .blue) {
                        VStack(spacing: 16) {
                            // 行程標題
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("標題")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if isEditingCustomLocation {
                                        Text("\(previewTitle.count)/50")
                                            .font(.system(size: 10))
                                            .foregroundColor(previewTitle.count >= 50 ? .red : .secondary)
                                    }
                                }
                                
                                // 如果是自定义位置且正在编辑，显示可编辑的 TextField
                                if isEditingCustomLocation {
                                    TextField("請輸入行程標題", text: $previewTitle)
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.systemGray6))
                                        )
                                } else {
                                    // 标题仅观看不编辑（显示预览内容）
                                    Text(previewTitle)
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.systemGray6))
                                        )
                                }
                            }
                            
                            // 活動內容（描述）
                            VStack(alignment: .leading, spacing: 4) {
                                Text("描述")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                // 如果是自定义位置且正在编辑，显示可编辑的 TextEditor
                                if isEditingCustomLocation {
                                    GlassTextEditor(
                                        placeholder: "請輸入活動描述",
                                        text: $previewDescription,
                                        minHeight: 80
                                    )
                                } else {
                                    // 描述仅观看不编辑（显示预览内容）
                                    ScrollView {
                                        Text(previewDescription.isEmpty ? "無描述" : previewDescription)
                                            .font(.system(size: 15))
                                            .foregroundColor(previewDescription.isEmpty ? .secondary : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 12)
                                    }
                                    .frame(minHeight: 80)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(UIColor.systemGray6))
                                    )
                                }
                            }
                            
                            // 選擇地點
                            VStack(alignment: .leading, spacing: 4) {
                                Text("地點")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                // 地点仅观看不编辑
                                Text(location.isEmpty ? "無地點" : location)
                                    .font(.system(size: 16))
                                    .foregroundColor(location.isEmpty ? .secondary : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(UIColor.systemGray6))
                                    )
                            }
                            
                            // 时间不显示（按照原先时间照旧）
                        }
                    }
                    
                }
                .padding(.bottom, 80) // 为底部按钮留出空间
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("編輯行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        hideKeyboard()
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("確定") {
                        hideKeyboard()
                        confirmSelection()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor((selectedAttraction != nil || isCustomLocation) ? .blue : .gray)
                    .disabled(selectedAttraction == nil && !isCustomLocation)
                }
            }
            .task {
                // 加载周边特色
                if !location.isEmpty {
                    await loadSurroundingFeatures()
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                NavigationView {
                    LocationPickerView(
                        selectedAddress: $customLocationAddress,
                        selectedCoordinate: $customLocationCoordinate
                    )
                    .navigationTitle("選擇地點")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .onDisappear {
                    // 地图选择器关闭后，如果选择了位置，更新预览内容
                    if !customLocationAddress.isEmpty {
                        handleCustomLocationSelected()
                    }
                }
            }
        }
    }
    
    // MARK: - 周边特色选择器
    private var surroundingAttractionsSelector: some View {
        EventFormCard(icon: "mappin.circle.fill", title: "周邊特色", iconColor: .orange) {
            VStack(spacing: 16) {
                // 分类选择器
                if !surroundingAttractions.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(AttractionSortType.allCases, id: \.self) { sortType in
                            Button(action: {
                                selectedSortType = sortType
                                Task {
                                    await loadSurroundingFeatures()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: sortType.icon)
                                        .font(.system(size: 12))
                                    Text(sortType.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(selectedSortType == sortType ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedSortType == sortType ? Color.blue : Color(.systemGray6))
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                
                if isLoadingSurroundingFeatures {
                    HStack {
                        ProgressView()
                        Text("載入中...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if surroundingAttractions.isEmpty {
                    Text("暫無周邊特色")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(surroundingAttractions) { attraction in
                            SurroundingAttractionButton(
                                attraction: attraction,
                                isSelected: selectedAttraction?.id == attraction.id && !isCustomLocation
                            ) {
                                // 点选后更新预览内容，不立即保存
                                selectedAttraction = attraction
                                isCustomLocation = false
                                updatePreviewContent(for: attraction)
                            }
                        }
                        
                        // 添加"其他"选项
                        Button(action: {
                            showLocationPicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(isCustomLocation ? .white : .primary)
                                
                                Text("其他")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(isCustomLocation ? .white : .primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isCustomLocation ? Color.blue : Color(.systemBackground))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isCustomLocation ? Color.clear : Color(UIColor.systemGray4), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - 加载周边特色
    private func loadSurroundingFeatures() async {
        guard !location.isEmpty else { return }
        
        isLoadingSurroundingFeatures = true
        
        // 1. 获取当前block的坐标
        await fetchCurrentBlockCoordinate()
        
        // 2. 获取后续行程位置（用于地理围栏）
        await fetchFutureRouteLocations()
        
        // 3. 获取已选择的特色地点（排除列表）
        let excludeAttractions = getExcludedAttractions()
        
        do {
            // 提取城市名（如果格式是"国家 - 城市"，只取城市部分）
            let cityName: String
            let countryName: String?
            if location.contains(" - ") {
                let components = location.components(separatedBy: " - ")
                countryName = components.first
                cityName = components.last ?? location
            } else {
                cityName = location
                countryName = nil
            }
            
            // 4. 首先尝试从城市资料库获取
            let database = CityAttractionsDatabase.shared
            var cityAttractions = database.getFilteredAttractions(
                for: cityName,
                country: countryName,
                interestTags: interestTags,
                sortBy: convertSortType(selectedSortType),
                referenceLocation: currentBlockCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) },
                routeLocations: getRouteLocations(),
                excludeAttractions: excludeAttractions,
                maxDistance: maxGeofenceDistance,
                futureRouteLocations: futureRouteLocations
            )
            
            // 5. 转换为SurroundingAttraction格式
            var attractions: [SurroundingAttraction] = cityAttractions.map { cityAttraction in
                SurroundingAttraction(
                    id: cityAttraction.id,
                    name: cityAttraction.name,
                    category: cityAttraction.category,
                    icon: cityAttraction.icon
                )
            }
            
            // 6. 如果资料库中没有足够的数据，使用API补充
            if attractions.count < 6 {
                let apiAttractions = try await fetchAttractionsFromAPI(
                    cityName: cityName,
                    excludeAttractions: excludeAttractions
                )
                
                // 合并并去重
                let existingNames = Set(attractions.map { $0.name.lowercased() })
                let newAttractions = apiAttractions.filter { attraction in
                    !existingNames.contains(attraction.name.lowercased())
                }
                attractions.append(contentsOf: newAttractions)
            }
            
            await MainActor.run {
                // 过滤掉已在行程中的景点（包括当前block和其他所有行程中的景点）
                let excludedNames = getExcludedAttractions().map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                let filteredAttractions = attractions.filter { attraction in
                    let attractionName = attraction.name.trimmingCharacters(in: .whitespaces).lowercased()
                    // 检查是否与任何已排除的景点名称匹配（支持部分匹配）
                    return !excludedNames.contains { excludedName in
                        attractionName.contains(excludedName) || excludedName.contains(attractionName)
                    }
                }
                
                // 根据排序类型重新排序
                self.surroundingAttractions = sortAttractions(filteredAttractions, by: selectedSortType)
                self.isLoadingSurroundingFeatures = false
            }
        } catch {
            print("❌ [BlockEditView] 获取周边特色失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingSurroundingFeatures = false
                // 使用默认特色
                self.surroundingAttractions = getDefaultAttractions()
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /// 获取当前block的坐标
    private func fetchCurrentBlockCoordinate() async {
        guard let locationString = block.location, !locationString.isEmpty else { return }
        
        // 使用GooglePlacesManager获取坐标
        let placesManager = GooglePlacesManager.shared
        await withCheckedContinuation { continuation in
            placesManager.searchPlaces(query: locationString, coordinate: nil) { result in
                Task { @MainActor in
                    if case .success(let places) = result, let firstPlace = places.first {
                        placesManager.fetchPlaceDetails(placeIDs: [firstPlace.placeID]) { detailsResult in
                            Task { @MainActor in
                                if case .success(let detailedPlaces) = detailsResult,
                                   let place = detailedPlaces.first {
                                    self.currentBlockCoordinate = place.coordinate
                                }
                                continuation.resume()
                            }
                        }
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    /// 获取后续行程位置（用于地理围栏）
    private func fetchFutureRouteLocations() async {
        guard let plan = plan else {
            futureRouteLocations = []
            return
        }
        
        var locations: [CLLocation] = []
        let calendar = Calendar.current
        let currentBlockDate = calendar.startOfDay(for: block.startTime)
        
        // 遍历所有天的行程
        for day in plan.days {
            let dayDate = calendar.startOfDay(for: day.date)
            
            // 只获取当前block之后的行程位置
            if dayDate > currentBlockDate || (dayDate == currentBlockDate && day.blocks.contains(where: { $0.startTime > block.startTime })) {
                for block in day.blocks where block.type == .activity {
                    if let locationString = block.location, !locationString.isEmpty {
                        // 异步获取坐标
                        let placesManager = GooglePlacesManager.shared
                        await withCheckedContinuation { continuation in
                            placesManager.searchPlaces(query: locationString, coordinate: nil) { result in
                                Task { @MainActor in
                                    if case .success(let places) = result, let firstPlace = places.first {
                                        placesManager.fetchPlaceDetails(placeIDs: [firstPlace.placeID]) { detailsResult in
                                            Task { @MainActor in
                                                if case .success(let detailedPlaces) = detailsResult,
                                                   let place = detailedPlaces.first {
                                                    locations.append(CLLocation(
                                                        latitude: place.coordinate.latitude,
                                                        longitude: place.coordinate.longitude
                                                    ))
                                                }
                                                continuation.resume()
                                            }
                                        }
                                    } else {
                                        continuation.resume()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        await MainActor.run {
            self.futureRouteLocations = locations
        }
    }
    
    /// 获取已选择的特色地点（排除列表）
    private func getExcludedAttractions() -> [String] {
        guard let plan = plan else { return [] }
        
        var excluded: Set<String> = []  // 使用 Set 避免重复
        
        // 收集所有行程中的地点名称和标题
        for day in plan.days {
            for block in day.blocks where block.type == .activity {
                // 添加 location（如果存在）
                if let location = block.location, !location.isEmpty {
                    excluded.insert(location)
                    // 如果 location 包含 " - "，也添加城市部分
                    if location.contains(" - ") {
                        let cityPart = location.components(separatedBy: " - ").last ?? location
                        excluded.insert(cityPart)
                    }
                }
                // 添加 title（如果存在且不为空）
                let title = block.title.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    excluded.insert(title)
                }
            }
        }
        
        return Array(excluded)
    }
    
    /// 获取路径位置（用于沿途排序）
    private func getRouteLocations() -> [CLLocation] {
        // 简化实现：返回当前block的坐标（如果可用）
        var locations: [CLLocation] = []
        
        if let coordinate = currentBlockCoordinate {
            locations.append(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
        
        // 可以扩展为获取更多路径位置
        return locations
    }
    
    /// 从API获取特色
    private func fetchAttractionsFromAPI(cityName: String, excludeAttractions: [String]) async throws -> [SurroundingAttraction] {
        // 构建提示词，包含兴趣偏好和排除列表
        var prompt = "推荐\(cityName)的4-8个知名地标或景点"
        if !interestTags.isEmpty {
            prompt += "，优先推荐与以下兴趣相关的：\(interestTags.joined(separator: "、"))"
        }
        // 添加排除列表到提示词中
        if !excludeAttractions.isEmpty {
            prompt += "，但不要推荐以下已在行程中的景点：\(excludeAttractions.joined(separator: "、"))"
        }
        prompt += "，只返回JSON数组：[\"景点1\",\"景点2\",...]"
        
        // 调用 OpenAI API
        let response = try await OpenAIManager.shared.generateSurroundingAttractions(
            prompt: prompt,
            timeout: 20.0
        )
        
        // 解析响应
        return parseSurroundingAttractions(response)
    }
    
    /// 转换排序类型
    private func convertSortType(_ sortType: AttractionSortType) -> CityAttractionsDatabase.AttractionSortType {
        switch sortType {
        case .distance: return .distance
        case .popularity: return .popularity
        case .route: return .route
        }
    }
    
    /// 排序特色列表
    private func sortAttractions(_ attractions: [SurroundingAttraction], by sortType: AttractionSortType) -> [SurroundingAttraction] {
        // 基础排序已在CityAttractionsDatabase中完成
        // 这里可以添加额外的排序逻辑
        return Array(attractions.prefix(8))
    }
    
    // MARK: - 解析周边特色响应
    private func parseSurroundingAttractions(_ jsonString: String) -> [SurroundingAttraction] {
        if let jsonData = jsonString.data(using: .utf8),
           let nameArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
            return parseAttractionsFromNameArray(nameArray)
        }
        
        // 如果JSON解析失败，尝试提取数组内容
        if let startRange = jsonString.range(of: "["),
           let endRange = jsonString.range(of: "]", range: startRange.upperBound..<jsonString.endIndex) {
            let arrayContent = String(jsonString[startRange.upperBound..<endRange.lowerBound])
            let names = arrayContent.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r\t")) }
                .filter { !$0.isEmpty }
            return parseAttractionsFromNameArray(names)
        }
        
        return []
    }
    
    private func parseAttractionsFromNameArray(_ nameArray: [String]) -> [SurroundingAttraction] {
        var attractions: [SurroundingAttraction] = []
        
        // 获取排除列表（用于过滤API返回的结果）
        let excludedNames = getExcludedAttractions().map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        
        for (index, name) in nameArray.enumerated() {
            guard !name.isEmpty else { continue }
            
            // 检查是否在排除列表中
            let nameLowercased = name.trimmingCharacters(in: .whitespaces).lowercased()
            let isExcluded = excludedNames.contains { excludedName in
                nameLowercased.contains(excludedName) || excludedName.contains(nameLowercased)
            }
            
            if isExcluded {
                continue  // 跳过已在行程中的景点
            }
            
            let (category, icon) = inferCategoryAndIcon(from: name)
            
            let attraction = SurroundingAttraction(
                id: "\(index)-\(name)",
                name: name,
                category: category,
                icon: icon
            )
            attractions.append(attraction)
        }
        
        return attractions
    }
    
    private func inferCategoryAndIcon(from name: String) -> (category: String, icon: String) {
        let lowercased = name.lowercased()
        
        if lowercased.contains("寺") || lowercased.contains("神宮") || lowercased.contains("神社") || lowercased.contains("廟") || lowercased.contains("教堂") || lowercased.contains("cathedral") {
            return ("宗教", "building.columns.fill")
        } else if lowercased.contains("公園") || lowercased.contains("park") || lowercased.contains("花園") || lowercased.contains("garden") {
            return ("公园", "tree.fill")
        } else if lowercased.contains("博物館") || lowercased.contains("museum") || lowercased.contains("美術館") || lowercased.contains("gallery") {
            return ("博物馆", "building.2.fill")
        } else if lowercased.contains("餐廳") || lowercased.contains("restaurant") || lowercased.contains("美食") || lowercased.contains("food") {
            return ("美食", "fork.knife")
        } else if lowercased.contains("塔") || lowercased.contains("tower") || lowercased.contains("橋") || lowercased.contains("bridge") {
            return ("地标", "binoculars.fill")
        } else if lowercased.contains("海") || lowercased.contains("beach") || lowercased.contains("湖") || lowercased.contains("lake") {
            return ("自然", "water.waves")
        } else {
            return ("景点", "mappin.circle.fill")
        }
    }
    
    private func getDefaultAttractions() -> [SurroundingAttraction] {
        return [
            SurroundingAttraction(id: "1", name: "知名地标", category: "地标", icon: "mappin.circle.fill"),
            SurroundingAttraction(id: "2", name: "历史建筑", category: "建筑", icon: "building.columns.fill"),
            SurroundingAttraction(id: "3", name: "自然景观", category: "自然", icon: "tree.fill"),
            SurroundingAttraction(id: "4", name: "文化景点", category: "文化", icon: "book.fill")
        ]
    }
    
    // MARK: - 周边特色按钮
    struct SurroundingAttractionButton: View {
        let attraction: SurroundingAttraction
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: attraction.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(attraction.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color(UIColor.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - 更新预览内容（选择周边特色后）
    private func updatePreviewContent(for attraction: SurroundingAttraction) {
        // 更新预览标题
        previewTitle = attraction.name
        
        // 更新预览描述（使用默认描述，保持简洁）
        if location.isEmpty {
            previewDescription = "\(attraction.name)是知名的\(attraction.category)景点。"
        } else {
            // 提取城市名
            let cityName: String
            if location.contains(" - ") {
                let components = location.components(separatedBy: " - ")
                cityName = components.last ?? location
            } else {
                cityName = location
            }
            previewDescription = "\(attraction.name)是\(cityName)的知名\(attraction.category)景点。"
        }
    }
    
    // MARK: - 处理自定义位置选择（从地图选择器返回后）
    private func handleCustomLocationSelected() {
        // 检查是否只是一串地址（没有名称）
        let isJustAddress = isJustAddressString(customLocationAddress)
        
        if isJustAddress {
            // 如果只是地址，允许用户编辑标题和描述
            isCustomLocation = true
            selectedAttraction = nil
            previewTitle = customLocationAddress
            previewDescription = ""
            isEditingCustomLocation = true
        } else {
            // 如果有名称，直接使用
            isCustomLocation = true
            selectedAttraction = nil
            previewTitle = customLocationAddress
            previewDescription = "自定義地點：\(customLocationAddress)"
            isEditingCustomLocation = false
        }
    }
    
    // MARK: - 判断是否只是地址字符串
    private func isJustAddressString(_ text: String) -> Bool {
        // 简单的启发式判断：如果包含常见的地址关键词，可能是地址
        let addressKeywords = ["路", "街", "道", "巷", "弄", "號", "號", "區", "市", "縣", "省", "路", "Street", "Avenue", "Road", "Lane", "District", "City", "Province"]
        let hasAddressKeywords = addressKeywords.contains { text.contains($0) }
        
        // 如果包含地址关键词，且长度较长，可能是地址
        if hasAddressKeywords && text.count > 15 {
            return true
        }
        
        // 如果包含数字和地址关键词，更可能是地址
        let hasNumbers = text.rangeOfCharacter(from: .decimalDigits) != nil
        if hasNumbers && hasAddressKeywords {
            return true
        }
        
        return false
    }
    
    // MARK: - 确认选择（点击确定按钮后）
    private func confirmSelection() {
        guard selectedAttraction != nil || isCustomLocation else { return }
        
        var updatedBlock = block
        updatedBlock.title = previewTitle
        updatedBlock.description = previewDescription.isEmpty ? nil : previewDescription
        
        // 更新地点信息
        if let attraction = selectedAttraction {
            // SurroundingAttraction 只有 name 属性，使用 name 作为地点
            updatedBlock.location = attraction.name
        } else if isCustomLocation {
            updatedBlock.location = customLocationAddress
        }
        
        // 保持原有的时间不变（时间调整在 PlanDetailView 的 updateBlock 中处理）
        
        // 调用 onSave 更新 block，但不关闭编辑页面
        // 让用户可以继续编辑其他 block
        onSave(updatedBlock)
        
        // 重置选择状态，准备下一次编辑
        // 使用更新后的值作为新的预览内容
        selectedAttraction = nil
        isCustomLocation = false
        previewTitle = updatedBlock.title
        previewDescription = updatedBlock.description ?? ""
        
        // 不调用 dismiss()，让用户继续停留在编辑状态
        // 用户可以继续选择其他周边特色或编辑其他 block
    }
}
