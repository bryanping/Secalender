//
//  WeekendFlashView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//  周末快闪功能：基于GPS位置直接显示6个周边特色，选择后安排一日游
//

import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 周末快闪步骤枚举
enum WeekendFlashStep: Int {
    case step1 = 1  // 周边特色选择
    case step2 = 2  // AI生成
}

struct WeekendFlashView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    // 步骤控制
    @State private var currentStep: WeekendFlashStep = .step1
    
    // GPS定位
    @StateObject private var locationManager = LocationPickerManager()
    @State private var currentGPSLocation: CLLocation? = nil
    @State private var gpsLocationAddress: String = ""
    @State private var isLocatingGPS = false
    @State private var hasAutoRequestedGPS = false
    @State private var locationCountryName: String = ""  // 定位的国家名（中文）
    @State private var locationCountryEnglish: String = ""  // 定位的国家名（英文）
    
    // 地点选择
    @State private var selectedCountry: String? = nil
    @State private var selectedCity: String? = nil
    @State private var showLocationPicker = false
    @State private var availableCities: [String] = []  // 当前国家的城市列表
    
    // 周边特色
    @State private var surroundingAttractions: [SurroundingAttraction] = []
    @State private var selectedSurroundingAttractions: Set<String> = []
    @State private var isLoadingSurroundingFeatures = false
    
    // AI生成
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0.0
    @State private var currentTask: String = ""
    @State private var completedTasks: [String] = []
    @State private var pendingTasks: [String] = []
    
    // 生成结果
    @State private var generatedPlan: PlanResult? = nil
    @State private var showPlanDetailView = false
    @State private var showPlanEditView = false
    @State private var planToEdit: PlanResult? = nil
    
    // 错误处理
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
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
                        Button("取消") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .sheet(item: $generatedPlan) { plan in
                NavigationView {
                    PlanDetailView(
                        plan: plan,
                        customTitle: "週末快閃行程",
                        onEdit: { planToEdit in
                            self.planToEdit = planToEdit
                            generatedPlan = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showPlanEditView = true
                            }
                        },
                        onAddToCalendar: nil,
                        onSaveToTemplate: nil,
                        onDismiss: {
                            generatedPlan = nil
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .sheet(isPresented: $showPlanEditView) {
                if let plan = planToEdit ?? generatedPlan {
                    PlanEditView(
                        plan: plan,
                        customTitle: "週末快閃行程",
                        onSaveToCalendar: {
                            showPlanEditView = false
                            generatedPlan = nil
                            dismiss()
                        },
                        onSaveToTemplate: { editedPlan, title in
                            savePlanToTemplate(editedPlan, title: title ?? "週末快閃行程")
                            generatedPlan = editedPlan
                            showPlanEditView = false
                        },
                        onDismiss: {
                            showPlanEditView = false
                            if let editedPlan = planToEdit {
                                generatedPlan = editedPlan
                            }
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("好") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showLocationPicker) {
                NavigationView {
                    CountryCityPickerView(
                        selectedCountry: $selectedCountry,
                        selectedCity: $selectedCity,
                        restrictedCountry: locationCountryName.isEmpty ? nil : locationCountryName,  // 限制只显示定位到的国家
                        onSelect: { country, city in
                            selectedCountry = country
                            selectedCity = city
                            // 选择城市后，加载该城市的周边特色
                            loadSurroundingFeatures(for: city)
                            showLocationPicker = false
                        }
                    )
                    .navigationTitle("選擇地點")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .onAppear {
                // 自动获取GPS位置
                if !hasAutoRequestedGPS {
                    hasAutoRequestedGPS = true
                    requestGPSLocation()
                }
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
        case .step1: return 50.0
        case .step2: return 100.0
        }
    }
    
    private var stepDisplayText: String {
        switch currentStep {
        case .step1: return "步驟 1/2"
        case .step2: return "步驟 2/2"
        }
    }
    
    private var navigationTitle: String {
        switch currentStep {
        case .step1: return "週末快閃"
        case .step2: return "智能規劃"
        }
    }
    
    // MARK: - 步骤1：地点和周边特色选择
    private var step1View: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题和副标题
            VStack(alignment: .leading, spacing: 8) {
                Text("選擇地點")
                    .font(.system(size: 28, weight: .bold))
                
                Text("基於您所在國家，選擇一個地點，我們為您推薦6個周邊特色景點。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // GPS定位状态（仅显示加载状态，不显示地址）
            if isLocatingGPS {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("正在定位...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            
            // 地点选择
            VStack(alignment: .leading, spacing: 16) {

                
                Button {
                    showLocationPicker = true
                } label: {
                    HStack {
                        Image(systemName: selectedCity == nil ? "mappin.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(selectedCity == nil ? .blue : .green)
                        if let country = selectedCountry, let city = selectedCity {
                            Text("\(country) - \(city)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        } else if !locationCountryName.isEmpty {
                            Text("點擊選擇 \(locationCountryName) 的地點")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("選擇地點")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedCity == nil ? Color.blue : Color(UIColor.systemGray4), lineWidth: 1)
                    )
                }
            }
            
            // 周边特色选择（仅在选择地点后显示）
            if selectedCity != nil {
                VStack(alignment: .leading, spacing: 16) {
                    Text("周邊特色")
                        .font(.headline)
                    
                    if isLoadingSurroundingFeatures {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("正在搜尋周邊特色...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    } else if surroundingAttractions.isEmpty {
                        Text("暫無周邊特色推薦")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            let currentSelectionCount = selectedSurroundingAttractions.count
                            if currentSelectionCount > 0 {
                                Text("已選擇 \(currentSelectionCount) 個景點")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(surroundingAttractions) { attraction in
                                    let isSelected = selectedSurroundingAttractions.contains(attraction.id)
                                    
                                    SurroundingAttractionButton(
                                        attraction: attraction,
                                        isSelected: isSelected
                                    ) {
                                        if isSelected {
                                            selectedSurroundingAttractions.remove(attraction.id)
                                        } else {
                                            selectedSurroundingAttractions.insert(attraction.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 步骤2：AI生成
    private var step2View: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("AI正在為您打造完美行程...")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("這個過程可能需要一些時間，請稍候")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 任务列表
            VStack(alignment: .leading, spacing: 16) {
                ForEach(completedTasks, id: \.self) { task in
                    TaskRow(task: task, status: .completed)
                }
                
                if !currentTask.isEmpty {
                    TaskRow(task: currentTask, status: .inProgress)
                }
                
                ForEach(pendingTasks, id: \.self) { task in
                    TaskRow(task: task, status: .pending)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            
            // 进度条
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("正在完成您的行程")
                        .font(.subheadline)
                    Spacer()
                    Text("\(completedTasks.count + (currentTask.isEmpty ? 0 : 1))/\(pendingTasks.count + completedTasks.count + (currentTask.isEmpty ? 0 : 1))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(UIColor.systemGray5))
                            .frame(height: 6)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * generationProgress, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }
    
    // MARK: - 底部按钮
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            if currentStep == .step1 {
                Button(action: {
                    goToNextStep()
                }) {
                    HStack {
                        Text("開始規劃一日遊")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(canProceedToStep2 ? Color.blue : Color.gray)
                    .cornerRadius(20)
                }
                .disabled(!canProceedToStep2)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var canProceedToStep2: Bool {
        selectedCity != nil && !selectedSurroundingAttractions.isEmpty
    }
    
    // MARK: - 导航方法
    private func goToNextStep() {
        withAnimation {
            currentStep = .step2
            startGeneration()
        }
    }
    
    private func goToPreviousStep() {
        withAnimation {
            currentStep = .step1
        }
    }
    
    // MARK: - GPS定位方法
    @MainActor
    private func requestGPSLocation() {
        isLocatingGPS = true
        gpsLocationAddress = ""
        locationCountryName = ""
        locationCountryEnglish = ""
        
        // 先尝试从缓存加载
        if let cachedCoordinate = LocationCacheManager.shared.loadLastLocation() {
            let cachedLocation = CLLocation(latitude: cachedCoordinate.latitude, longitude: cachedCoordinate.longitude)
            currentGPSLocation = cachedLocation
            reverseGeocodeLocation(cachedLocation)
            isLocatingGPS = false
            return
        }
        
        locationManager.requestPermission()
        
        Task {
            let startTime = Date()
            while locationManager.currentLocation == nil && Date().timeIntervalSince(startTime) < 5.0 {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            
            if let location = locationManager.currentLocation {
                currentGPSLocation = location
                LocationCacheManager.shared.saveLastLocation(location)
                reverseGeocodeLocation(location)
            } else {
                if let location = await locationManager.requestLocationOnce() {
                    currentGPSLocation = location
                    LocationCacheManager.shared.saveLastLocation(location)
                    reverseGeocodeLocation(location)
                } else {
                    isLocatingGPS = false
                    gpsLocationAddress = "定位失败，请检查位置权限设置"
                }
            }
        }
    }
    
    private func reverseGeocodeLocation(_ location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                self.isLocatingGPS = false
                if let placemark = placemarks?.first {
                    var addressComponents: [String] = []
                    if let name = placemark.name { addressComponents.append(name) }
                    if let locality = placemark.locality { 
                        addressComponents.append(locality)
                    }
                    if let administrativeArea = placemark.administrativeArea { addressComponents.append(administrativeArea) }
                    if let country = placemark.country { 
                        addressComponents.append(country)
                        // 保存国家名（英文）
                        self.locationCountryEnglish = country
                        // 转换为中文国家名
                        let convertedCountry = self.convertCountryToChinese(country)
                        
                        // 验证转换后的国家名是否在数据中存在
                        let dataManager = DestinationDataManager.shared
                        let allCountries = dataManager.getAllCountries()
                        
                        // 如果转换后的国家名不在列表中，尝试搜索匹配
                        if allCountries.contains(convertedCountry) {
                            self.locationCountryName = convertedCountry
                        } else {
                            // 尝试搜索匹配（支持简繁体）
                            let matchedCountries = dataManager.searchCountries(country)
                            if let matchedCountry = matchedCountries.first {
                                self.locationCountryName = matchedCountry
                            } else {
                                // 如果还是找不到，使用转换后的名称（可能不在数据中）
                                self.locationCountryName = convertedCountry
                                print("⚠️ [WeekendFlashView] 国家 \(country) 转换后为 \(convertedCountry)，但不在数据列表中")
                            }
                        }
                        
                        // 设置默认选择的国家
                        if self.selectedCountry == nil && !self.locationCountryName.isEmpty {
                            self.selectedCountry = self.locationCountryName
                        }
                    }
                    self.gpsLocationAddress = addressComponents.joined(separator: ", ")
                } else {
                    self.gpsLocationAddress = "位置: \(location.coordinate.latitude), \(location.coordinate.longitude)"
                }
            }
        }
    }
    
    // MARK: - 国家名称转换
    private func convertCountryToChinese(_ englishCountry: String) -> String {
        // 国家英文名到中文名的映射
        let countryMap: [String: String] = [
            "China": "中國",
            "Japan": "日本",
            "South Korea": "韓國",
            "Taiwan": "台灣",
            "Thailand": "泰國",
            "Singapore": "新加坡",
            "Malaysia": "馬來西亞",
            "Vietnam": "越南",
            "Indonesia": "印尼",
            "Philippines": "菲律賓",
            "Greece": "希臘",
            "Germany": "德國",
            "United Kingdom": "英國",
            "Italy": "義大利",
            "Spain": "西班牙",
            "France": "法國",
            "Austria": "奧地利",
            "United States": "美國",
            "Mexico": "墨西哥",
            "Turkey": "土耳其"
        ]
        
        // 直接匹配
        if let chinese = countryMap[englishCountry] {
            return chinese
        }
        
        // 部分匹配（处理 "United States of America" 等情况）
        for (english, chinese) in countryMap {
            if englishCountry.contains(english) {
                return chinese
            }
        }
        
        // 如果找不到，返回英文名
        return englishCountry
    }
    
    // MARK: - 加载城市列表
    private func loadCitiesForCountry() {
        guard let country = selectedCountry else { return }
        let dataManager = DestinationDataManager.shared
        
        // 如果国家是"中國"，需要特殊处理（包含旅游景点）
        if country == "中國" {
            let (cities, attractions) = dataManager.getCitiesGrouped(for: country)
            availableCities = cities + attractions
        } else {
            availableCities = dataManager.getCities(for: country)
        }
    }
    
    // MARK: - 加载周边特色（基于选择的地点）
    private func loadSurroundingFeatures(for cityName: String) {
        guard !cityName.isEmpty else { return }
        
        // 清空之前的选择
        selectedSurroundingAttractions = []
        surroundingAttractions = []
        
        isLoadingSurroundingFeatures = true
        
        Task {
            do {
                let attractions = try await withTimeout(seconds: 20) {
                    try await self.fetchSurroundingAttractions(for: cityName)
                }
                
                await MainActor.run {
                    // 确保返回6个特色
                    self.surroundingAttractions = Array(attractions.prefix(6))
                    if self.surroundingAttractions.count < 6 {
                        // 如果少于6个，用默认值补充
                        let defaultAttractions = self.getDefaultAttractions()
                        let needed = 6 - self.surroundingAttractions.count
                        self.surroundingAttractions.append(contentsOf: defaultAttractions.prefix(needed))
                    }
                    self.isLoadingSurroundingFeatures = false
                }
            } catch {
                print("❌ [WeekendFlashView] 获取周边特色失败: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingSurroundingFeatures = false
                    // 使用默认特色
                    self.surroundingAttractions = Array(self.getDefaultAttractions().prefix(6))
                }
            }
        }
    }
    
    private func fetchSurroundingAttractions(for cityName: String) async throws -> [SurroundingAttraction] {
        let prompt = "推荐\(cityName)的6个知名地标或景点，只返回JSON数组：[\"景点1\",\"景点2\",...]"
        
        let response = try await OpenAIManager.shared.generateSurroundingAttractions(
            prompt: prompt,
            timeout: 20.0
        )
        
        return parseSurroundingAttractions(response)
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "WeekendFlashView", code: -1, userInfo: [NSLocalizedDescriptionKey: "请求超时"])
            }
            
            guard let result = try await group.next() else {
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "任务组返回空结果"])
            }
            group.cancelAll()
            return result
        }
    }
    
    private func parseSurroundingAttractions(_ jsonString: String) -> [SurroundingAttraction] {
        if let jsonData = jsonString.data(using: .utf8),
           let nameArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
            return parseAttractionsFromNameArray(nameArray)
        }
        
        if let jsonStart = jsonString.range(of: "["),
           let jsonEnd = jsonString.range(of: "]", options: .backwards),
           let jsonSubstring = jsonString[jsonStart.lowerBound..<jsonEnd.upperBound].data(using: .utf8),
           let nameArray = try? JSONSerialization.jsonObject(with: jsonSubstring) as? [String] {
            return parseAttractionsFromNameArray(nameArray)
        }
        
        return getDefaultAttractions()
    }
    
    private func parseAttractionsFromNameArray(_ nameArray: [String]) -> [SurroundingAttraction] {
        var attractions: [SurroundingAttraction] = []
        
        for (index, name) in nameArray.enumerated() {
            guard !name.isEmpty else { continue }
            
            let (category, icon) = inferCategoryAndIcon(from: name)
            
            let attraction = SurroundingAttraction(
                id: "\(index)",
                name: name,
                category: category,
                icon: icon
            )
            attractions.append(attraction)
        }
        
        return attractions
    }
    
    private func inferCategoryAndIcon(from name: String) -> (category: String, icon: String) {
        let lowercasedName = name.lowercased()
        
        if lowercasedName.contains("塔") || lowercasedName.contains("大樓") || lowercasedName.contains("tower") {
            return ("地标", "building.2")
        }
        
        if lowercasedName.contains("博物館") || lowercasedName.contains("museum") {
            return ("文化", "book")
        }
        
        if lowercasedName.contains("寺") || lowercasedName.contains("temple") {
            return ("文化", "building.columns")
        }
        
        if lowercasedName.contains("公園") || lowercasedName.contains("park") {
            return ("自然", "tree")
        }
        
        if lowercasedName.contains("市場") || lowercasedName.contains("market") {
            return ("购物", "bag")
        }
        
        if lowercasedName.contains("美食") || lowercasedName.contains("restaurant") {
            return ("美食", "fork.knife")
        }
        
        return ("景点", "location.circle")
    }
    
    private func getDefaultAttractions() -> [SurroundingAttraction] {
        return [
            SurroundingAttraction(id: "default_1", name: "知名地标", category: "地标", icon: "building.2"),
            SurroundingAttraction(id: "default_2", name: "文化景点", category: "景点", icon: "building.columns"),
            SurroundingAttraction(id: "default_3", name: "自然景观", category: "景点", icon: "tree"),
            SurroundingAttraction(id: "default_4", name: "美食街区", category: "美食", icon: "fork.knife"),
            SurroundingAttraction(id: "default_5", name: "购物中心", category: "购物", icon: "bag"),
            SurroundingAttraction(id: "default_6", name: "艺术空间", category: "文化", icon: "paintpalette"),
        ]
    }
    
    // MARK: - AI生成
    private func startGeneration() {
        guard currentGPSLocation != nil, !selectedSurroundingAttractions.isEmpty else {
            errorMessage = "缺少必要信息"
            showErrorAlert = true
            return
        }
        
        currentStep = .step2
        isGenerating = true
        generationProgress = 0.0
        completedTasks = []
        currentTask = ""
        
        pendingTasks = [
            "正在分析目的地資訊",
            "正在規劃活動安排",
            "正在優化路線",
            "正在生成完整行程"
        ]
        
        Task {
            await generatePlan()
        }
    }
    
    private func generatePlan() async {
        guard let city = selectedCity else {
            await MainActor.run {
                errorMessage = "缺少地点信息"
                showErrorAlert = true
                isGenerating = false
            }
            return
        }
        
        // 获取选中的周边特色名称
        let selectedAttractionNames = surroundingAttractions
            .filter { selectedSurroundingAttractions.contains($0.id) }
            .map { $0.name }
        
        // 使用选择的城市作为目的地
        let destination = city
        
        // 固定为一日游
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = startDate
        
        var slots = ExtractedSlots()
        slots.destination = SlotInfo(value: destination, confidence: 1.0)
        slots.dateRange = SlotInfo(value: DateRange(startDate: startDate, endDate: endDate), confidence: 1.0)
        slots.interestTags = []  // 周末快闪不需要兴趣偏好
        slots.budgetLevel = SlotInfo(value: .moderate, confidence: 1.0)
        slots.pace = SlotInfo(value: .moderate, confidence: 1.0)
        slots.transportPreference = SlotInfo(value: .publicTransport, confidence: 1.0)  // 默认大众运输
        
        let classificationResult = ClassificationResult(
            inputType: .typeA,
            slots: slots,
            assumptions: [],
            riskFlags: []
        )
        
        let apiTask = Task {
            let plan = try await generateAIPoweredPlan(from: classificationResult, selectedAttractions: selectedAttractionNames)
            await MainActor.run {
                generatedPlan = plan
            }
        }
        
        // 任务列表动画
        await MainActor.run {
            currentTask = pendingTasks.removeFirst()
            generationProgress = 0.25
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.5
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.75
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        await MainActor.run {
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
        }
        
        do {
            _ = try await apiTask.value
            
            await MainActor.run {
                if !currentTask.isEmpty {
                    completedTasks.append(currentTask)
                    currentTask = ""
                }
                generationProgress = 1.0
                
                if let plan = generatedPlan {
                    Task { @MainActor in
                        await convertAndSavePlan(plan)
                    }
                }
            }
        } catch {
            await MainActor.run {
                if !currentTask.isEmpty {
                    currentTask = ""
                }
                errorMessage = "生成行程失败：\(error.localizedDescription)"
                showErrorAlert = true
                isGenerating = false
            }
        }
    }
    
    private func generateAIPoweredPlan(from result: ClassificationResult, selectedAttractions: [String]) async throws -> PlanResult {
        guard let destination = result.slots.destination.value else {
            throw PlanGenerationError.missingDestination
        }
        
        guard let dateRange = result.slots.dateRange.value else {
            throw PlanGenerationError.missingDateInfo
        }
        
        // 固定为1天
        let numberOfDays = 1
        
        let aiPlan = try await AITripGenerator.shared.generateAIItinerary(
            destination: destination,
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
            durationDays: numberOfDays,
            interestTags: [],
            pace: .moderate,
            walkingLevel: nil,
            transportPreference: .publicTransport,
            selectedAttractions: selectedAttractions,
            currentGPSLocation: currentGPSLocation,
            accommodationAddress: nil,
            accommodationType: nil
        )
        
        var plan = try AITripGenerator.shared.convertToPlanResult(aiPlan, slots: result.slots)
        plan.assumptions = result.assumptions
        
        return plan
    }
    
    @MainActor
    private func convertAndSavePlan(_ plan: PlanResult) async {
        isGenerating = false
        savePlanToTemplate(plan, title: "週末快閃行程")
        generatedPlan = plan
        
        if !plan.days.isEmpty {
            showPlanDetailView = true
        } else {
            errorMessage = "生成的行程数据无效"
            showErrorAlert = true
        }
    }
    
    private func savePlanToTemplate(_ plan: PlanResult, title: String) {
        let userId = userManager.userOpenId
        
        let templateTitle = title
        let destination = SavedTripTemplate.extractDestination(from: plan)
        
        let template = SavedTripTemplate(
            title: templateTitle,
            plan: plan,
            savedDate: Date(),
            tags: [],
            destination: destination
        )
        
        TripTemplateManager.shared.saveTemplate(template, for: userId)
        
        print("✅ 行程已保存到模板：\(templateTitle)")
    }
}

// MARK: - 复用组件
extension WeekendFlashView {
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
                .background(isSelected ? Color.blue : Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color(UIColor.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    struct TaskRow: View {
        let task: String
        let status: TaskStatus
        
        enum TaskStatus {
            case completed
            case inProgress
            case pending
        }
        
        var body: some View {
            HStack(spacing: 12) {
                switch status {
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .inProgress:
                    ProgressView()
                        .scaleEffect(0.8)
                case .pending:
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                }
                
                Text(task)
                    .font(.subheadline)
                    .foregroundColor(status == .pending ? .secondary : .primary)
            }
        }
    }
}
