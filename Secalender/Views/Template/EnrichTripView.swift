//
//  EnrichTripView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//  充实行程功能：先填写基本行程信息，然后搜索并选择周边选项，最后自动排定当日行程
//

import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 步骤枚举
enum EnrichTripStep: Int {
    case step1 = 1  // 填写基本行程信息
    case step2 = 2  // 搜索并选择周边选项
    case step3 = 3  // 预览并确认行程
}

// MARK: - 地点类别枚举（更新为美食、旅店、景点、休闲娱乐）
enum PlaceCategory: String, CaseIterable {
    case restaurant = "restaurant"  // 美食
    case hotel = "hotel"            // 旅店
    case attraction = "attraction"  // 景点
    case entertainment = "entertainment"  // 休闲娱乐
    
    @MainActor
    var displayName: String {
        switch self {
        case .restaurant: return "enrich_trip.category.restaurant".localized()
        case .hotel: return "enrich_trip.category.hotel".localized()
        case .attraction: return "enrich_trip.category.attraction".localized()
        case .entertainment: return "enrich_trip.category.entertainment".localized()
        }
    }
    
    var searchKeyword: String {
        switch self {
        case .restaurant: return "restaurant"
        case .hotel: return "hotel"
        case .attraction: return "attraction"
        case .entertainment: return "entertainment"
        }
    }
    
    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .hotel: return "bed.double.fill"
        case .attraction: return "camera.fill"
        case .entertainment: return "gamecontroller.fill"
        }
    }
}

// MARK: - 地点结果模型
struct EnrichPlaceResult: Identifiable {
    let id: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let category: PlaceCategory
    let types: [String]
}

// MARK: - 行程项模型（用于排定当日行程）
struct ScheduledEventItem: Identifiable {
    let id = UUID()
    let place: EnrichPlaceResult
    var startTime: Date
    var endTime: Date
    var title: String
    var information: String
}

struct EnrichTripView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    // 步骤控制
    @State private var currentStep: EnrichTripStep = .step1
    
    // Step 1: 基本行程信息
    @State private var tripTitle: String = ""
    @State private var tripContent: String = ""
    @State private var tripDestination: String = ""
    @State private var tripCoordinate: CLLocationCoordinate2D? = nil
    @State private var tripDate: Date = Date()
    @State private var tripStartTime: Date = Date()
    @State private var tripEndTime: Date = Date()
    @State private var showLocationPicker = false
    
    // Step 2: 周边选项搜索
    @State private var selectedCategory: PlaceCategory? = nil
    @State private var searchResults: [EnrichPlaceResult] = []
    @State private var selectedPlaces: Set<String> = []  // 存储选中的地点ID
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>? = nil
    
    // Step 3: 行程排定
    @State private var scheduledEvents: [ScheduledEventItem] = []
    @State private var isSaving = false
    
    // 错误处理
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    private let placesManager = GooglePlacesManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 进度指示器
                    progressIndicator
                    
                    // 内容区域
                    ScrollView {
                        VStack(spacing: 24) {
                            switch currentStep {
                            case .step1:
                                step1View
                            case .step2:
                                step2View
                            case .step3:
                                step3View
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    
                    // 底部按钮
                    bottomButtons
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep != .step1 {
                        Button(action: {
                            goToPreviousStep()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                    } else {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentStep == .step1 {
                        Button("common.cancel".localized()) {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(
                    selectedAddress: $tripDestination,
                    selectedCoordinate: Binding(
                        get: { tripCoordinate },
                        set: { newValue in
                            tripCoordinate = newValue
                            showLocationPicker = false
                        }
                    )
                )
            }
            .alert("common.error".localized(), isPresented: $showErrorAlert) {
                Button("common.ok".localized(), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - 进度指示器
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Text(stepDisplayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progressPercentage))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progressPercentage / 100, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private var progressPercentage: Double {
        switch currentStep {
        case .step1: return 33.0
        case .step2: return 66.0
        case .step3: return 100.0
        }
    }
    
    private var stepDisplayText: String {
        switch currentStep {
        case .step1: return "步驟 1/3"
        case .step2: return "步驟 2/3"
        case .step3: return "步驟 3/3"
        }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case .step1: return "enrich_trip.title".localized()
        case .step2: return "enrich_trip.select_surrounding".localized()
        case .step3: return "enrich_trip.review_schedule".localized()
        }
    }
    
    // MARK: - Step 1: 填写基本行程信息
    private var step1View: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题和描述
            VStack(alignment: .leading, spacing: 8) {
                Text("enrich_trip.step1_title".localized())
                    .font(.system(size: 28, weight: .bold))
                
                Text("enrich_trip.step1_description".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 表单
            EventFormCard(icon: "calendar", title: "enrich_trip.basic_info".localized(), iconColor: .blue) {
                VStack(spacing: 16) {
                    // 行程标题
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("event_create.title".localized())
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(tripTitle.count)/20")
                                .font(.system(size: 10))
                                .foregroundColor(tripTitle.count >= 20 ? .red : .secondary)
                        }
                        
                        TextField("event_create.title_placeholder".localized(), text: Binding(
                            get: { tripTitle },
                            set: { newValue in
                                if newValue.count <= 20 {
                                    tripTitle = newValue
                                }
                            }
                        ))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray6))
                        )
                    }
                    
                    // 活动内容
                    VStack(alignment: .leading, spacing: 4) {
                        Text("event_create.content".localized())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        GlassTextEditor(
                            placeholder: "event_create.content_placeholder".localized(),
                            text: $tripContent,
                            minHeight: 80
                        )
                    }
                    
                    // 选择地点
                    VStack(alignment: .leading, spacing: 4) {
                        Text("event_create.select_location".localized())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showLocationPicker = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                                
                                if tripDestination.isEmpty {
                                    Text("event_create.select_location".localized())
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(tripDestination)
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemGray6))
                            )
                        }
                    }
                    
                    // 选择时间
                    VStack(alignment: .leading, spacing: 4) {
                        Text("event_create.set_time".localized())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        DatePicker("", selection: $tripDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        
                        HStack {
                            DatePicker("", selection: $tripStartTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                            
                            Text("—")
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $tripEndTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Step 2: 搜索并选择周边选项
    private var step2View: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题和描述
            VStack(alignment: .leading, spacing: 8) {
                Text("enrich_trip.step2_title".localized())
                    .font(.system(size: 28, weight: .bold))
                
                Text("enrich_trip.step2_description".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 类别选择
            VStack(alignment: .leading, spacing: 12) {
                Text("enrich_trip.select_category".localized())
                    .font(.headline)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(PlaceCategory.allCases, id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                            searchNearbyPlaces()
                        }
                    }
                }
            }
            
            // 搜索结果
            if isSearching {
                searchingView
            } else if !searchResults.isEmpty {
                resultsSection
            } else if tripCoordinate != nil {
                noResultsView
            }
        }
    }
    
    // MARK: - Step 3: 预览并确认行程
    private var step3View: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题和描述
            VStack(alignment: .leading, spacing: 8) {
                Text("enrich_trip.step3_title".localized())
                    .font(.system(size: 28, weight: .bold))
                
                Text("enrich_trip.step3_description".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 基本行程信息
            EventFormCard(icon: "calendar", title: "enrich_trip.main_trip".localized(), iconColor: .blue) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tripTitle)
                        .font(.headline)
                    
                    if !tripContent.isEmpty {
                        Text(tripContent)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                        Text(tripDestination)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text(formatDateTime(tripDate, startTime: tripStartTime, endTime: tripEndTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 排定的周边行程
            if !scheduledEvents.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("enrich_trip.surrounding_events".localized())
                        .font(.headline)
                    
                    ForEach(scheduledEvents) { event in
                        ScheduledEventCard(event: event)
                    }
                }
            }
        }
    }
    
    // MARK: - 底部按钮
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                handleNextButton()
            }) {
                HStack {
                    if (currentStep == .step3 && isSaving) {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text(nextButtonTitle)
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canProceed || (currentStep == .step3 && isSaving))
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var nextButtonTitle: String {
        switch currentStep {
        case .step1: return "enrich_trip.next".localized()
        case .step2: return "enrich_trip.next".localized()
        case .step3: return "enrich_trip.save_schedule".localized()
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .step1:
            return !tripTitle.isEmpty && !tripDestination.isEmpty && tripCoordinate != nil
        case .step2:
            return !selectedPlaces.isEmpty
        case .step3:
            return true
        }
    }
    
    // MARK: - 搜索结果区域
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("enrich_trip.search_results".localized(with: searchResults.count))
                .font(.headline)
            
            LazyVStack(spacing: 12) {
                ForEach(searchResults) { place in
                    PlaceCard(
                        place: place,
                        isSelected: selectedPlaces.contains(place.id)
                    ) {
                        togglePlaceSelection(place)
                    }
                }
            }
        }
    }
    
    // MARK: - 搜索中视图
    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("enrich_trip.searching".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - 无结果视图
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("enrich_trip.no_results".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - 排定的行程卡片
    private struct ScheduledEventCard: View {
        let event: ScheduledEventItem
        
        var body: some View {
            HStack(spacing: 12) {
                // 时间
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(event.startTime))
                        .font(.headline)
                    Text(formatTime(event.endTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 60)
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                    
                    if !event.information.isEmpty {
                        Text(event.information)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(event.place.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        
        private func formatTime(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
    }
    
    // MARK: - 类别按钮
    private struct CategoryButton: View {
        let category: PlaceCategory
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : categoryColor)
                    
                    Text(category.displayName)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSelected ? categoryColor : Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
                )
            }
        }
        
        private var categoryColor: Color {
            switch category {
            case .restaurant: return .orange
            case .hotel: return .blue
            case .attraction: return .green
            case .entertainment: return .purple
            }
        }
    }
    
    // MARK: - 地点卡片
    private struct PlaceCard: View {
        let place: EnrichPlaceResult
        let isSelected: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: place.category.icon)
                            .foregroundColor(categoryColor)
                            .font(.system(size: 20))
                    }
                    
                    // 信息
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(place.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // 选择标记
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? categoryColor : .gray)
                        .font(.system(size: 24))
                }
                .padding()
                .background(isSelected ? categoryColor.opacity(0.1) : Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? categoryColor : Color.clear, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        private var categoryColor: Color {
            switch place.category {
            case .restaurant: return .orange
            case .hotel: return .blue
            case .attraction: return .green
            case .entertainment: return .purple
            }
        }
    }
    
    // MARK: - 步骤导航
    private func goToPreviousStep() {
        withAnimation {
            switch currentStep {
            case .step2:
                currentStep = .step1
            case .step3:
                currentStep = .step2
            case .step1:
                break
            }
        }
    }
    
    private func handleNextButton() {
        switch currentStep {
        case .step1:
            // 验证并进入下一步
            if canProceed {
                withAnimation {
                    currentStep = .step2
                }
                // 自动搜索所有类别
                searchNearbyPlaces()
            }
        case .step2:
            // 排定行程
            scheduleEvents()
            withAnimation {
                currentStep = .step3
            }
        case .step3:
            // 保存所有行程
            saveAllEvents()
        }
    }
    
    // MARK: - 搜索附近地点
    private func searchNearbyPlaces() {
        guard let coordinate = tripCoordinate else { return }
        
        // 取消之前的搜索
        searchTask?.cancel()
        
        isSearching = true
        searchResults = []
        
        // 创建新的搜索任务
        searchTask = Task {
            // 防抖：等待 300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard !Task.isCancelled else { return }
            
            await performSearch(coordinate: coordinate)
        }
    }
    
    @MainActor
    private func performSearch(coordinate: CLLocationCoordinate2D) async {
        defer { isSearching = false }
        
        // 如果选择了特定类别，只搜索该类别；否则搜索所有类别
        let categoriesToSearch = selectedCategory != nil ? [selectedCategory!] : PlaceCategory.allCases
        
        var allResults: [EnrichPlaceResult] = []
        
        // 并行搜索所有类别
        await withTaskGroup(of: [EnrichPlaceResult].self) { group in
            for category in categoriesToSearch {
                group.addTask {
                    await searchCategory(category: category, coordinate: coordinate)
                }
            }
            
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }
        
        // 限制结果数量（每个类别最多5个）
        var categoryCounts: [PlaceCategory: Int] = [:]
        searchResults = allResults.filter { place in
            let count = categoryCounts[place.category] ?? 0
            if count < 5 {
                categoryCounts[place.category] = count + 1
                return true
            }
            return false
        }
    }
    
    @MainActor
    private func searchCategory(category: PlaceCategory, coordinate: CLLocationCoordinate2D) async -> [EnrichPlaceResult] {
        // 构建搜索查询
        let query = "\(tripDestination) \(category.searchKeyword)"
        
        return await withCheckedContinuation { continuation in
            placesManager.searchPlaces(query: query, coordinate: coordinate) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let places):
                        // 获取详细信息
                        let placeIDs = places.map { $0.placeID }
                        placesManager.fetchPlaceDetails(placeIDs: placeIDs) { detailsResult in
                            Task { @MainActor in
                                switch detailsResult {
                                case .success(let detailedPlaces):
                                    var results: [EnrichPlaceResult] = []
                                    for place in detailedPlaces {
                                        let enrichPlace = EnrichPlaceResult(
                                            id: place.placeID,
                                            name: place.name,
                                            address: place.address,
                                            coordinate: place.coordinate,
                                            category: category,
                                            types: place.types
                                        )
                                        results.append(enrichPlace)
                                    }
                                    continuation.resume(returning: results)
                                    
                                case .failure:
                                    continuation.resume(returning: [])
                                }
                            }
                        }
                        
                    case .failure:
                        continuation.resume(returning: [])
                    }
                }
            }
        }
    }
    
    // MARK: - 切换地点选择
    private func togglePlaceSelection(_ place: EnrichPlaceResult) {
        if selectedPlaces.contains(place.id) {
            selectedPlaces.remove(place.id)
        } else {
            selectedPlaces.insert(place.id)
        }
    }
    
    // MARK: - 排定行程
    private func scheduleEvents() {
        // 获取选中的地点
        let selectedPlacesList = searchResults.filter { selectedPlaces.contains($0.id) }
        
        // 基于主行程的结束时间开始排定
        var currentTime = tripEndTime
        
        scheduledEvents = selectedPlacesList.map { place in
            // 每个地点默认1.5小时
            let duration: TimeInterval = 1.5 * 60 * 60
            let startTime = currentTime
            let endTime = currentTime.addingTimeInterval(duration)
            
            currentTime = endTime.addingTimeInterval(30 * 60) // 预留30分钟移动时间
            
            return ScheduledEventItem(
                place: place,
                startTime: startTime,
                endTime: endTime,
                title: place.name,
                information: ""
            )
        }
    }
    
    // MARK: - 保存所有行程
    private func saveAllEvents() {
        isSaving = true
        
        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm:ss"
                
                // 保存主行程
                var mainEvent = Event(
                    title: tripTitle,
                    creatorOpenid: userManager.userOpenId,
                    color: "#FF6280",
                    date: dateFormatter.string(from: tripDate),
                    startTime: timeFormatter.string(from: tripStartTime),
                    endTime: timeFormatter.string(from: tripEndTime),
                    destination: tripDestination,
                    mapObj: "",
                    openChecked: 0,
                    personChecked: 0,
                    createTime: "",
                    information: tripContent,
                    isAllDay: false,
                    repeatType: "never",
                    calendarComponent: "default"
                )
                
                try await EventManager.shared.addEvent(event: mainEvent)
                
                // 保存周边行程
                for scheduledEvent in scheduledEvents {
                    var event = Event(
                        title: scheduledEvent.title,
                        creatorOpenid: userManager.userOpenId,
                        color: "#FF6280",
                        date: dateFormatter.string(from: scheduledEvent.startTime),
                        startTime: timeFormatter.string(from: scheduledEvent.startTime),
                        endTime: timeFormatter.string(from: scheduledEvent.endTime),
                        destination: scheduledEvent.place.address,
                        mapObj: "",
                        openChecked: 0,
                        personChecked: 0,
                        createTime: "",
                        information: scheduledEvent.information,
                        isAllDay: false,
                        repeatType: "never",
                        calendarComponent: "default"
                    )
                    
                    try await EventManager.shared.addEvent(event: event)
                }
                
                // 通知刷新
                NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = String(format: "enrich_trip.save_failed".localized(), error.localizedDescription)
                    showErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - 辅助函数
    private func formatDateTime(_ date: Date, startTime: Date, endTime: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        return "\(dateFormatter.string(from: date)) \(timeFormatter.string(from: startTime))-\(timeFormatter.string(from: endTime))"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
