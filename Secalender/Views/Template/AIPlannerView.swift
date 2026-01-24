//
//  AIPlannerView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  重新设计：步骤式AI规划界面
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 步骤枚举
enum PlanningStep: Int {
    case step1 = 1  // 基本信息
    case step2 = 2  // 偏好设置
    case step3 = 3  // 行程細節優化
    case step4 = 4  // AI生成
}

// MARK: - 交通方式枚举
enum TransportationType: String, CaseIterable {
    case publicTransport = "大眾運輸"
    case selfDrive = "租車自駕"
    case charteredCar = "包車服務"
    
    var icon: String {
        switch self {
        case .publicTransport: return "bus.fill"
        case .selfDrive: return "car.fill"
        case .charteredCar: return "person.fill"
        }
    }
    
    var description: String {
        switch self {
        case .publicTransport: return "地鐵、巴士、火車"
        case .selfDrive: return "享受自由掌控的旅程"
        case .charteredCar: return "專業司機,尊榮接送"
        }
    }
}

// MARK: - 周邊特色数据结构
struct SurroundingAttraction: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String  // 分类，如"地标"、"景点"、"美食"等
    let icon: String
    
    static func == (lhs: SurroundingAttraction, rhs: SurroundingAttraction) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - 周邊特色枚举（保留用于兼容）
enum SurroundingFeature: String, CaseIterable {
    case localFestivals = "在地慶典"
    case hiddenGems = "隱藏秘境"
    case instagramSpots = "網美打卡"
    case artisticCafes = "文青咖啡"
    
    var icon: String {
        switch self {
        case .localFestivals: return "sparkles"
        case .hiddenGems: return "location.circle"
        case .instagramSpots: return "camera.fill"
        case .artisticCafes: return "cup.and.saucer.fill"
        }
    }
}

// MARK: - 特殊限制枚举
enum SpecialRestriction: String, CaseIterable {
    case childFriendly = "兒童友善"
    case wheelchairAccess = "輪椅通道"
    case indoorPriority = "室內優先"
    case earlyRest = "提早休息"
    
    var icon: String {
        switch self {
        case .childFriendly: return "figure.child"
        case .wheelchairAccess: return "figure.roll"
        case .indoorPriority: return "house.fill"
        case .earlyRest: return "moon.fill"
        }
    }
}

// MARK: - 兴趣标签
enum InterestTag: String, CaseIterable {
    case food = "美食"
    case history = "歷史"
    case nature = "自然"
    case shopping = "購物"
    case nightlife = "夜生活"
    case art = "藝術"
//    case adventure = "冒險"
//    case wellness = "身心健康"
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .history: return "building.columns"
        case .nature: return "tree"
        case .shopping: return "bag"
        case .nightlife: return "wineglass"
        case .art: return "paintpalette"
//        case .adventure: return "figure.climbing"
//        case .wellness: return "figure.mind.and.body"
        }
    }
}

// MARK: - BudgetLevel 扩展（用于UI显示）
extension BudgetLevel {
    var displayName: String {
        switch self {
        case .low: return "經濟"
        case .moderate: return "標準"
        case .high: return "奢華"
        }
    }
    
    var symbol: String {
        switch self {
        case .low: return "$"
        case .moderate: return "$$"
        case .high: return "$$$"
        }
    }
}

struct AIPlannerView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    // 步骤控制
    @State private var currentStep: PlanningStep = .step1
    
    // 步骤1：基本信息
    @State private var tripTheme: String = ""
    @State private var destination: String = ""
    @State private var selectedDestination: String? = nil  // 快速选择
    @State private var selectedCountry: String? = nil
    @State private var selectedCity: String? = nil
    @State private var showLocationPicker = false
    
    // 旅行天数
    @State private var travelDays: Int = 3
    
    // 同行人数
    @State private var adults: Int = 1
    @State private var children: Int = 0
    
    // 步骤2：偏好设置
    @State private var selectedInterests: Set<InterestTag> = []
    @State private var selectedTransportation: TransportationType? = .publicTransport
    @State private var selectedPace: Pace = .moderate
    @State private var budgetLevel: BudgetLevel = .moderate
    
    // 步骤3：行程細節優化
    @State private var surroundingAttractions: [SurroundingAttraction] = []
    @State private var selectedSurroundingAttractions: Set<String> = []  // 存储选中的ID
    @State private var isLoadingSurroundingFeatures = false
    @State private var selectedRestrictions: Set<SpecialRestriction> = []
    @State private var additionalRequirements: String = ""
    
    // 步骤4：AI生成
    @State private var isGenerating = false
    @State private var generationProgress: Double = 0.0
    @State private var currentTask: String = ""
    @State private var completedTasks: [String] = []
    @State private var pendingTasks: [String] = []
    
    // 生成结果
    @State private var generatedPlan: PlanResult? = nil
    @State private var showPlanDetailView = false
    @State private var showPlanEditView = false
    @State private var planToEdit: PlanResult? = nil  // 用于编辑的 plan
    
    // 错误处理
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // 目的地历史记录（使用 @AppStorage 持久化）
    @AppStorage("destinationHistory") private var destinationHistoryData: Data = Data()
    
    // 计算属性：从历史记录中获取快速目的地选项（只显示城市名，最多4个）
    private var quickDestinations: [String] {
        guard let history = try? JSONDecoder().decode([String].self, from: destinationHistoryData) else {
            // 如果没有历史记录，返回默认值
            return ["東京", "京都", "大阪"]
        }
        // 提取城市名（如果格式是"国家 - 城市"，只取城市部分）
        // 只显示最后4个（最新的在前面，所以取前4个）
        let cityNames = history.prefix(4).map { dest -> String in
            if dest.contains(" - ") {
                // 提取城市名（"国家 - 城市" 格式）
                let components = dest.components(separatedBy: " - ")
                return components.last ?? dest
            }
            return dest
        }
        return Array(cityNames)
    }
    
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
                            case .step4:
                                step4View
                            }
                        }
                        .padding()
                    }
                    
                    // 底部按钮
                    bottomButtons
                }
            }
            .navigationTitle(
                currentStep == .step1 ? "行程基礎" :
                currentStep == .step2 ? "進階設定" :
                currentStep == .step3 ? "行程細節" : "智能規劃"
            )
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
            .sheet(isPresented: $showLocationPicker) {
                NavigationView {
                    CountryCityPickerView(
                        selectedCountry: $selectedCountry,
                        selectedCity: $selectedCity,
                        onSelect: { country, city in
                            selectedCountry = country
                            selectedCity = city
                            let newDestination = "\(country) - \(city)"
                            destination = newDestination
                            saveDestinationToHistory(newDestination)
                            showLocationPicker = false
                        }
                    )
                    .navigationTitle("選擇地點")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            // 修复：使用 generatedPlan 直接驱动 sheet，避免首次空白
            // PlanResult 已经是 Identifiable，可以直接用 sheet(item:)
            .sheet(item: $generatedPlan) { plan in
                NavigationView {
                    PlanDetailView(
                        plan: plan,
                        customTitle: tripTheme.isEmpty ? nil : tripTheme,  // 传递用户填写的标题
                        onEdit: { planToEdit in
                            // 编辑功能：打开 PlanEditView
                            self.planToEdit = planToEdit
                            // 先关闭详情页
                            generatedPlan = nil
                            // 然后打开编辑页（需要短暂延迟确保 sheet 切换流畅）
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showPlanEditView = true
                            }
                        },
                        onAddToCalendar: nil,  // 不再需要这个功能
                        onSaveToTemplate: nil,  // 已自动保存，不需要保存按钮
                        onDismiss: {
                            // 关闭详情页
                            generatedPlan = nil
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .sheet(isPresented: $showPlanEditView) {
                // 修复：确保 plan 数据在 sheet 打开时已经准备好
                if let plan = planToEdit ?? generatedPlan {
                    PlanEditView(
                        plan: plan,
                        customTitle: tripTheme.isEmpty ? nil : tripTheme,  // 传递用户填写的"此行的主題"
                        onSaveToCalendar: {
                            // 保存到日历后，关闭编辑页面，然后关闭 AIPlannerView（流程完成）
                            showPlanEditView = false
                            generatedPlan = nil
                            dismiss()  // 流程完成，关闭 AIPlannerView
                        },
                        onSaveToTemplate: { editedPlan, title in
                            // 修复：使用编辑后的 PlanResult，而不是进入编辑页前的 generatedPlan
                            savePlanToTemplate(editedPlan, title: title)
                            // 更新 generatedPlan 为编辑后的版本
                            generatedPlan = editedPlan
                            showPlanEditView = false
                            // 重新打开详情页显示编辑后的内容
                            generatedPlan = editedPlan
                        },
                        onDismiss: {
                            // 退出编辑页面，返回详情页
                            showPlanEditView = false
                            if let editedPlan = planToEdit {
                                generatedPlan = editedPlan
                            }
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            // 修复：删除 onChange dismiss 逻辑，避免多重 dismiss
            // PlanDetailView 关闭时只关闭自己的 sheet，AIPlannerView 只在流程完成时 dismiss
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("好") {}
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
    
    // 修复：统一进度显示，改为 4 步，进度按 25/50/75/100 走
    private var progressPercentage: Double {
        switch currentStep {
        case .step1: return 25.0
        case .step2: return 50.0
        case .step3: return 75.0
        case .step4: return 100.0
        }
    }
    
    // 修复：统一步骤文本，显示为 4/4
    private var stepDisplayText: String {
        switch currentStep {
        case .step1: return "步驟 1/4"
        case .step2: return "步驟 2/4"
        case .step3: return "步驟 3/4"
        case .step4: return "步驟 4/4"
        }
    }
    
    // MARK: - 步骤1：基本信息
    private var step1View: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 标题和副标题
            VStack(alignment: .leading, spacing: 8) {
                Text("告訴我們您的旅行計畫")
                    .font(.system(size: 28, weight: .bold))
                
                Text("讓我們從基本資訊開始,為您打造完美的行程。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
    }
    
            // 主题输入
            VStack(alignment: .leading, spacing: 8) {
                Text("此行的主題?")
                    .font(.headline)
                
                TextField("例如:京都之夏、東京美食之旅", text: $tripTheme)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                    )
            }
            
            // 目的地输入（国家-城市选择器）
            VStack(alignment: .leading, spacing: 8) {
                Text("你要去哪裡?")
                    .font(.headline)
                
                Button(action: {
                    showLocationPicker = true
                }) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                        Text(destination.isEmpty ? "搜尋目的地..." : destination)
                            .foregroundColor(destination.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                    )
                }
                
                // 快速选择按钮（只显示城市名）
                if !quickDestinations.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(quickDestinations, id: \.self) { cityName in
                            Button(action: {
                                // 从历史记录中找到完整的目的地字符串
                                let fullDestination = findFullDestination(for: cityName)
                                destination = fullDestination ?? cityName
                                selectedDestination = cityName
                                selectedCountry = nil
                                selectedCity = nil
                                saveDestinationToHistory(destination)
                            }) {
                                Text(cityName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedDestination == cityName ? Color.blue : Color(.systemGray6))
                                    .foregroundColor(selectedDestination == cityName ? .white : .blue)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(selectedDestination == cityName ? Color.clear : Color(UIColor.systemGray4).opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
    
            // 旅行天数
            VStack(alignment: .leading, spacing: 8) {
                Text("旅行天數")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    
                    Text("總共天數")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 天数选择器（带增减按钮）
                    HStack(spacing: 16) {
                        Button(action: {
                            if travelDays > 1 {
                                travelDays -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(travelDays > 1 ? .blue : .gray)
                        }
                        .disabled(travelDays <= 1)
                        
                        Text("\(travelDays)天")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(minWidth: 50)
                        
                        Button(action: {
                            if travelDays < 30 {
                                travelDays += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(travelDays < 30 ? .blue : .gray)
                        }
                        .disabled(travelDays >= 30)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                )
            }
            
            // 同行人数
            VStack(alignment: .leading, spacing: 8) {
                Text("同行人數")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    // 大人 - 独立容器
                    HStack {
                        // 左侧：文字信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text("大人")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("13歲以上")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 右侧：控制器（水平排列）
                        HStack(spacing: 16) {
                            // 减号按钮（圆形，灰色边框，蓝色图标）
                            Button(action: {
                                if adults > 1 {
                                    adults -= 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(adults > 1 ? Color.blue : Color(UIColor.systemGray4), lineWidth: 1.5)
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(adults > 1 ? .blue : Color(UIColor.systemGray3))
                                }
                            }
                            .disabled(adults <= 1)
                            
                            // 数字显示
                            Text("\(adults)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(minWidth: 30)
                            
                            // 加号按钮（圆形，蓝色填充，白色图标）
                            Button(action: {
                                if adults < 20 {
                                    adults += 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(adults < 20 ? Color.blue : Color(UIColor.systemGray4))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(adults >= 20)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                    )
                    
                    // 小孩 - 独立容器
                    HStack {
                        // 左侧：文字信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text("小孩")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("2-12歲")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 右侧：控制器（水平排列）
                        HStack(spacing: 16) {
                            // 减号按钮（圆形，灰色边框，蓝色图标）
                            Button(action: {
                                if children > 0 {
                                    children -= 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .stroke(children > 0 ? Color.blue : Color(UIColor.systemGray4), lineWidth: 1.5)
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(children > 0 ? .blue : Color(UIColor.systemGray3))
                                }
                            }
                            .disabled(children <= 0)
                            
                            // 数字显示
                            Text("\(children)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(minWidth: 30)
                            
                            // 加号按钮（圆形，蓝色填充，白色图标）
                            Button(action: {
                                if children < 20 {
                                    children += 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(children < 20 ? Color.blue : Color(UIColor.systemGray4))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(children >= 20)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                    )
                }
            }
                }
            }
            
    // MARK: - 步骤2：偏好设置
    private var step2View: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            
            // 交通方式
            VStack(alignment: .leading, spacing: 16) {
                Text("交通方式")
                    .font(.system(size: 20, weight: .semibold))
                
                VStack(spacing: 12) {
                    ForEach(TransportationType.allCases, id: \.self) { transport in
                        TransportationCard(
                            type: transport,
                            isSelected: selectedTransportation == transport
                        ) {
                            selectedTransportation = transport
                        }
                    }
                }
            }
            
            // 兴趣偏好
            VStack(alignment: .leading, spacing: 16) {
                Text("興趣偏好")
                    .font(.system(size: 20, weight: .semibold))
                
                // 按钮布局（2列，与特殊限制一致）
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(InterestTag.allCases.prefix(6), id: \.self) { tag in
                        InterestTagButton(
                            tag: tag,
                            isSelected: selectedInterests.contains(tag)
                        ) {
                            if selectedInterests.contains(tag) {
                                selectedInterests.remove(tag)
                            } else {
                                selectedInterests.insert(tag)
                            }
                        }
                    }
                }
            }
            
            // 特殊限制
            VStack(alignment: .leading, spacing: 16) {
                Text("特殊需求")
                    .font(.system(size: 20, weight: .semibold))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(SpecialRestriction.allCases, id: \.self) { restriction in
                        SpecialRestrictionButton(
                            restriction: restriction,
                            isSelected: selectedRestrictions.contains(restriction)
                        ) {
                            if selectedRestrictions.contains(restriction) {
                                selectedRestrictions.remove(restriction)
                            } else {
                                selectedRestrictions.insert(restriction)
                            }
                        }
                    }
                }
            }
            
            
            // 預算等級
            VStack(alignment: .leading, spacing: 16) {
                Text("預算等級")
                    .font(.system(size: 20, weight: .semibold))
                
                Picker("預算等級", selection: $budgetLevel) {
                    ForEach(BudgetLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    
    // MARK: - 步骤3：行程細節優化
    private var step3View: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 标题和副标题
            VStack(alignment: .leading, spacing: 8) {
                Text("行程細節優化")
                    .font(.system(size: 28, weight: .bold))
                
                Text("微調細節,讓我們為您推薦最精確的地點。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 周邊特色
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text("周邊特色")
                        .font(.system(size: 20, weight: .semibold))
                }
                
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
                    // 计算最多可选择数量（天数+1）
                    let maxSelection = travelDays + 1
                    let currentSelectionCount = selectedSurroundingAttractions.count
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if currentSelectionCount > 0 {
                            Text("已選擇 \(currentSelectionCount)/\(maxSelection) 個景點")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(surroundingAttractions) { attraction in
                                let isSelected = selectedSurroundingAttractions.contains(attraction.id)
                                let isDisabled = !isSelected && currentSelectionCount >= maxSelection
                                
                                SurroundingAttractionButton(
                                    attraction: attraction,
                                    isSelected: isSelected
                                ) {
                                    if isSelected {
                                        selectedSurroundingAttractions.remove(attraction.id)
                                    } else if currentSelectionCount < maxSelection {
                                        selectedSurroundingAttractions.insert(attraction.id)
                                    } else {
                                        // 修复：已达上限时显示提示（可选，如果需要的话）
                                        // 这里可以添加 Toast 提示，但为了简化，我们只禁用按钮
                                    }
                                }
                                .opacity(isDisabled ? 0.5 : 1.0)
                                .disabled(isDisabled)  // 修复：添加 disabled，避免可点击但无反应
                            }
                        }
                    }
                }
            }
            // 移除 onAppear 中的自动加载，改为在步骤1点击下一步时开始加载
            // 如果进入步骤3时还在加载，显示加载状态；如果已加载完成，显示结果
            // 行程節奏
            VStack(alignment: .leading, spacing: 16) {
                Text("行程節奏")
                    .font(.system(size: 20, weight: .semibold))
                
                VStack(spacing: 12) {
                    PaceOption(
                        title: "輕鬆",
                        description: "每天2-3個景點,步調悠閒",
                        isSelected: selectedPace == .relaxed
                    ) {
                        selectedPace = .relaxed
                    }
                    
                    PaceOption(
                        title: "中等",
                        description: "每天3-5個景點,充實適中",
                        isSelected: selectedPace == .moderate
                    ) {
                        selectedPace = .moderate
                    }
                    
                    PaceOption(
                        title: "緊湊",
                        description: "每日行程滿檔,不留遺憾",
                        isSelected: selectedPace == .tight
                    ) {
                        selectedPace = .tight
                    }
                }
            }
            
            
            // 其他需求
            VStack(alignment: .leading, spacing: 16) {
                Text("其他需求")
                    .font(.system(size: 20, weight: .semibold))
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $additionalRequirements)
                        .frame(height: 100)
                        .padding(4)
                    
                    if additionalRequirements.isEmpty {
                        Text("還有其他想告訴AI的嗎?例如:不吃生食、對花粉過敏...")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - 步骤4：AI生成
    private var step4View: some View {
        VStack(spacing: 32) {
            // 中央图标
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
            }
            
            // 周围图标
            HStack(spacing: 40) {
                Image(systemName: "cloud")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
                
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                
                Image(systemName: "fork.knife")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                
                Image(systemName: "house.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
            
            // 标题和副标题
        VStack(spacing: 8) {
                Text("AI正在為您打造完美行程...")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("這通常需要約10秒鐘")
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
                    Text("3/3")
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
                
                // 进度点
                HStack {
                    ForEach(0..<3) { index in
                            Circle()
                                .fill(index == 2 ? Color.blue : Color(UIColor.systemGray5))
                                .frame(width: 8, height: 8)
                    }
                            }
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
                        Text("下一步:偏好設定")
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
            } else if currentStep == .step2 {
                HStack(spacing: 12) {
                    Button(action: {
                        goToPreviousStep()
                    }) {
                        Text("上一步")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        goToNextStep()
                    }) {
                        Text("下一步")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }
            } else if currentStep == .step3 {
                HStack(spacing: 12) {
                    Button(action: {
                        goToPreviousStep()
                    }) {
                        Text("上一步")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        goToNextStep()
                    }) {
                        Text("完成設定")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }
            }
        }
        .padding()
                .background(Color(UIColor.systemBackground))
    }
    
    private var canProceedToStep2: Bool {
        !destination.isEmpty && travelDays > 0
    }
    
    // MARK: - 辅助视图
    
    // 兴趣偏好按钮（与特殊限制按钮样式一致）
    struct InterestTagButton: View {
        let tag: InterestTag
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: tag.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .blue : .primary)
                    
                    Text(tag.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
            }
        }
    }
    
    // 交通方式卡片
    struct TransportationCard: View {
        let type: TransportationType
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(type.description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    }
                }
                .padding()
                .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
            }
        }
    }
    
    // 行程節奏选项
    struct PaceOption: View {
        let title: String
        let description: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    // 单选圆圈
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 12, height: 12)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
            }
        }
    }
    
    // 周邊特色按钮（新版本，使用 SurroundingAttraction）
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
    
    // 周邊特色按钮（旧版本，保留用于兼容）
    struct SurroundingFeatureButton: View {
        let feature: SurroundingFeature
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(feature.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
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
    
    // 特殊限制按钮
    struct SpecialRestrictionButton: View {
        let restriction: SpecialRestriction
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: restriction.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .blue : .primary)
                    
                    Text(restriction.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color(UIColor.systemGray4), lineWidth: isSelected ? 2 : 1)
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
    
    // MARK: - 辅助方法
    
    // 从历史记录中查找完整的目的地字符串（用于城市名匹配）
    private func findFullDestination(for cityName: String) -> String? {
        guard let history = try? JSONDecoder().decode([String].self, from: destinationHistoryData) else {
            return nil
        }
        // 查找包含该城市名的完整目的地字符串
        return history.first { dest in
            if dest.contains(" - ") {
                let components = dest.components(separatedBy: " - ")
                return components.last == cityName
            }
            return dest == cityName
        }
    }
    
    // 保存目的地到历史记录
    private func saveDestinationToHistory(_ destination: String) {
        guard !destination.isEmpty else { return }
        
        // 从历史记录中读取现有列表
        var history: [String] = []
        if let existingHistory = try? JSONDecoder().decode([String].self, from: destinationHistoryData) {
            history = existingHistory
        }
        
        // 移除重复项（如果已存在）
        history.removeAll { $0 == destination }
        
        // 将新目的地添加到最前面（最近使用的在前面）
        history.insert(destination, at: 0)
        
        // 限制历史记录数量（只保留最后4个，删除旧的）
        if history.count > 4 {
            history = Array(history.prefix(4))
        }
        
        // 保存回 UserDefaults
        if let encoded = try? JSONEncoder().encode(history) {
            destinationHistoryData = encoded
        }
    }
    
    // 通过 OpenAI API 获取周邊特色（带超时处理）
    private func loadSurroundingFeatures() {
        guard !destination.isEmpty else { return }
        
        isLoadingSurroundingFeatures = true
        
        Task {
            do {
                // 使用 withTimeout 包装，避免无限等待
                let attractions = try await withTimeout(seconds: 20) {
                    try await self.fetchSurroundingAttractions()
                }
                
                await MainActor.run {
                    self.surroundingAttractions = attractions
                    self.isLoadingSurroundingFeatures = false
                }
            } catch {
                print("❌ [AIPlannerView] 获取周边特色失败: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingSurroundingFeatures = false
                    // 如果失败，使用默认的特色（4-8个）
                    let defaultAttractions = self.getDefaultAttractions()
                    self.surroundingAttractions = Array(defaultAttractions.prefix(6)) // 默认返回6个
                }
            }
        }
    }
    
    // 超时包装函数
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // 添加实际任务
            group.addTask {
                try await operation()
            }
            
            // 添加超时任务
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "AIPlannerView", code: -1, userInfo: [NSLocalizedDescriptionKey: "请求超时"])
            }
            
            // 返回第一个完成的任务结果
            // 修复：避免 force unwrap，使用 guard let
            guard let result = try await group.next() else {
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "任务组返回空结果"])
            }
            group.cancelAll() // 取消其他任务
            return result
        }
    }
    
    // 调用 OpenAI API 获取周边特色（只基于城市，不考虑兴趣偏好和特殊需求）
    private func fetchSurroundingAttractions() async throws -> [SurroundingAttraction] {
        // 提取城市名（如果格式是"国家 - 城市"，只取城市部分）
        let cityName: String
        if destination.contains(" - ") {
            let components = destination.components(separatedBy: " - ")
            cityName = components.last ?? destination
        } else {
            cityName = destination
        }
        
        // 构建提示词（只基于城市，不考虑兴趣偏好和特殊需求）
        // 兴趣偏好和特殊需求将在最后生成行程时再考虑
        let prompt = "推荐\(cityName)的4-8个知名地标或景点，只返回JSON数组：[\"景点1\",\"景点2\",...]"
        
        // 调用 OpenAI API（带超时处理）
        let response = try await OpenAIManager.shared.generateSurroundingAttractions(
            prompt: prompt,
            timeout: 20.0  // 15秒超时
        )
        
        // 解析响应
        return parseSurroundingAttractions(response)
    }
    
    // 解析周边特色响应（只包含名称的字符串数组）
    private func parseSurroundingAttractions(_ jsonString: String) -> [SurroundingAttraction] {
        // 首先尝试解析为字符串数组
        if let jsonData = jsonString.data(using: .utf8),
           let nameArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
            return parseAttractionsFromNameArray(nameArray)
        }
        
        // 如果失败，尝试提取JSON部分
        if let jsonStart = jsonString.range(of: "["),
           let jsonEnd = jsonString.range(of: "]", options: .backwards),
           let jsonSubstring = jsonString[jsonStart.lowerBound..<jsonEnd.upperBound].data(using: .utf8),
           let nameArray = try? JSONSerialization.jsonObject(with: jsonSubstring) as? [String] {
            return parseAttractionsFromNameArray(nameArray)
        }
        
        // 向后兼容：尝试解析为对象数组（旧格式）
        if let jsonData = jsonString.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
            return parseAttractionsFromObjectArray(jsonArray)
        }
        
        return getDefaultAttractions()
    }
    
    // 从名称数组解析周边特色（新格式）
    private func parseAttractionsFromNameArray(_ nameArray: [String]) -> [SurroundingAttraction] {
        var attractions: [SurroundingAttraction] = []
        
        for (index, name) in nameArray.enumerated() {
            guard !name.isEmpty else { continue }
            
            // 根据名称自动推断分类和图标
            let (category, icon) = inferCategoryAndIcon(from: name)
            
            let attraction = SurroundingAttraction(
                id: "\(index)",
                name: name,
                category: category,
                icon: icon
            )
            attractions.append(attraction)
        }
        
        // 接受4-8个结果，不强制补充
        // 如果少于4个，用默认值补充到至少4个
        if attractions.count < 4 {
            let defaultAttractions = getDefaultAttractions()
            let needed = 4 - attractions.count
            attractions.append(contentsOf: defaultAttractions.prefix(needed))
        }
        
        // 最多返回8个
        return Array(attractions.prefix(8))
    }
    
    // 从对象数组解析周边特色（向后兼容旧格式）
    private func parseAttractionsFromObjectArray(_ jsonArray: [[String: Any]]) -> [SurroundingAttraction] {
        var attractions: [SurroundingAttraction] = []
        
        for (index, dict) in jsonArray.enumerated() {
            guard let name = dict["name"] as? String,
                  !name.isEmpty else { continue }
            
            let category = dict["category"] as? String ?? "景点"
            let icon = dict["icon"] as? String ?? "location.circle"
            
            let attraction = SurroundingAttraction(
                id: "\(index)",
                name: name,
                category: category,
                icon: icon
            )
            attractions.append(attraction)
        }
        
        // 接受4-8个结果，不强制补充
        // 如果少于4个，用默认值补充到至少4个
        if attractions.count < 4 {
            let defaultAttractions = getDefaultAttractions()
            let needed = 4 - attractions.count
            attractions.append(contentsOf: defaultAttractions.prefix(needed))
        }
        
        // 最多返回8个
        return Array(attractions.prefix(8))
    }
    
    // 根据名称推断分类和图标
    private func inferCategoryAndIcon(from name: String) -> (category: String, icon: String) {
        let lowercasedName = name.lowercased()
        
        // 地标/建筑
        if lowercasedName.contains("塔") || 
           lowercasedName.contains("大樓") || lowercasedName.contains("大厦") ||
           lowercasedName.contains("tower") || lowercasedName.contains("building") {
            return ("地标", "building.2")
        }
        
        // 博物馆/文化
        if lowercasedName.contains("博物館") || lowercasedName.contains("博物馆") ||
           lowercasedName.contains("美術館") || lowercasedName.contains("美术馆") ||
           lowercasedName.contains("museum") || lowercasedName.contains("gallery") {
            return ("文化", "book")
        }
        
        // 寺庙/宗教
        if lowercasedName.contains("寺") || lowercasedName.contains("廟") ||
           lowercasedName.contains("神社") || lowercasedName.contains("temple") ||
           lowercasedName.contains("shrine") {
            return ("文化", "building.columns")
        }
        
        // 公园/自然
        if lowercasedName.contains("公園") || lowercasedName.contains("公园") ||
           lowercasedName.contains("park") ||
           lowercasedName.contains("山") || lowercasedName.contains("mountain") {
            return ("自然", "tree")
        }
        
        // 市场/购物
        if lowercasedName.contains("市場") || lowercasedName.contains("市场") ||
           lowercasedName.contains("商店街") || lowercasedName.contains("market") ||
           lowercasedName.contains("mall") {
            return ("购物", "bag")
        }
        
        // 美食
        if lowercasedName.contains("美食") || lowercasedName.contains("餐廳") ||
           lowercasedName.contains("餐厅") || lowercasedName.contains("restaurant") ||
           lowercasedName.contains("food") {
            return ("美食", "fork.knife")
        }
        
        // 默认
        return ("景点", "location.circle")
    }
    
    // 获取默认周边特色（作为备用）
    private func getDefaultAttractions() -> [SurroundingAttraction] {
        return [
            SurroundingAttraction(id: "default_1", name: "知名地标", category: "地标", icon: "building.2"),
            SurroundingAttraction(id: "default_2", name: "文化景点", category: "景点", icon: "building.columns"),
            SurroundingAttraction(id: "default_3", name: "自然景观", category: "景点", icon: "tree"),
            SurroundingAttraction(id: "default_4", name: "美食街区", category: "美食", icon: "fork.knife"),
            SurroundingAttraction(id: "default_5", name: "购物中心", category: "购物", icon: "bag"),
            SurroundingAttraction(id: "default_6", name: "艺术空间", category: "文化", icon: "paintpalette"),
            SurroundingAttraction(id: "default_7", name: "历史建筑", category: "历史", icon: "building"),
            SurroundingAttraction(id: "default_8", name: "观景台", category: "景点", icon: "binoculars"),
            SurroundingAttraction(id: "default_9", name: "主题公园", category: "娱乐", icon: "figure.play"),
            SurroundingAttraction(id: "default_10", name: "博物馆", category: "文化", icon: "book"),
            SurroundingAttraction(id: "default_11", name: "夜市", category: "美食", icon: "moon.stars"),
            SurroundingAttraction(id: "default_12", name: "特色街区", category: "景点", icon: "map")
        ]
    }
    
    // MARK: - 导航方法
    
    private func goToNextStep() {
        withAnimation {
            switch currentStep {
            case .step1:
                currentStep = .step2
                // 当从步骤1进入步骤2时，开始后台获取周边特色（只基于城市）
                if !destination.isEmpty && surroundingAttractions.isEmpty && !isLoadingSurroundingFeatures {
                    loadSurroundingFeatures()
                }
            case .step2:
                currentStep = .step3
            case .step3:
                currentStep = .step4
                startGeneration()
            case .step4:
                break
            }
        }
    }
    
    private func goToPreviousStep() {
        withAnimation {
            switch currentStep {
            case .step2:
                currentStep = .step1
            case .step3:
                currentStep = .step2
            case .step4:
                currentStep = .step3
            default:
                break
            }
        }
    }
    
    // MARK: - AI生成
    
    private func startGeneration() {
        guard !destination.isEmpty, travelDays > 0 else { return }
        
        currentStep = .step4
        isGenerating = true
        generationProgress = 0.0
        completedTasks = []
        currentTask = ""
        
        // 初始化任务列表（更详细的任务，让用户感觉在运作）
        pendingTasks = [
            "正在尋找\(destination)附近的優質飯店",
            "正在分析目的地資訊",
            "正在規劃活動安排",
            "正在優化日期分配",
            "正在安排休息時間",
            "正在檢查景點開放時間",
            "正在優化每日路線",
            "正在生成完整行程"
        ]
        
        Task {
            await generatePlan()
        }
    }
    
    private func generatePlan() async {
        // 构建分类结果（使用天数计算日期范围）
        let calendar = Calendar.current
        let startDate = Date() // 从今天开始
        let endDate = calendar.date(byAdding: .day, value: travelDays - 1, to: startDate) ?? startDate
        
        var slots = ExtractedSlots()
        slots.destination = SlotInfo(value: destination, confidence: 1.0)
        slots.dateRange = SlotInfo(value: DateRange(startDate: startDate, endDate: endDate), confidence: 1.0)
        slots.interestTags = selectedInterests.map { $0.rawValue }
        slots.budgetLevel = SlotInfo(value: budgetLevel, confidence: 1.0)
        slots.pace = SlotInfo(value: selectedPace, confidence: 1.0)
        
        // 转换交通方式
        if let transport = selectedTransportation {
            switch transport {
            case .publicTransport:
                slots.transportPreference = SlotInfo(value: .publicTransport, confidence: 1.0)
            case .selfDrive:
                slots.transportPreference = SlotInfo(value: .taxi, confidence: 0.8) // 使用taxi作为自驾的近似
            case .charteredCar:
                slots.transportPreference = SlotInfo(value: .taxi, confidence: 1.0)
            }
        }
        
        let classificationResult = ClassificationResult(
            inputType: .typeA,
            slots: slots,
            assumptions: [],
            riskFlags: []
        )
        
        // 修复：统一错误处理，只在外部 catch，apiTask 内部不处理错误
        // 并行执行：任务列表动画 + OpenAI API 调用
        let apiTask = Task {
            // apiTask 内部不 catch，让错误传播到外层统一处理
            let plan = try await generateAIPoweredPlan(from: classificationResult)
            await MainActor.run {
                generatedPlan = plan
            }
        }
        
        // 任务列表动画（与 API 调用并行，不等待 API 响应）
        // 任务1: 分析目的地資訊
        await MainActor.run {
            currentTask = pendingTasks.removeFirst()
            generationProgress = 0.1
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 1秒
        
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.2
        }
        
        // 任务2: 規劃活動安排
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.35
        }
        
        // 任务3: 優化日期分配
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.5
        }
        
        // 任务4: 安排休息時間
        try? await Task.sleep(nanoseconds: 4_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.65
        }
        
        // 任务5: 檢查景點開放時間
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.8
        }
        
        // 任务6: 優化每日路線
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 1秒
        await MainActor.run {
            completedTasks.append(currentTask)
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
            generationProgress = 0.9
        }
        
        // 任务7: 生成完整行程（等待 API 调用完成）
        await MainActor.run {
            if !pendingTasks.isEmpty {
                currentTask = pendingTasks.removeFirst()
            }
        }
        
        // 修复：统一错误处理，只在这里处理一次
        do {
            // 等待 API 调用完成
            _ = try await apiTask.value
            
            // API 调用成功，转换并保存
            await MainActor.run {
                if !currentTask.isEmpty {
                    completedTasks.append(currentTask)
                    currentTask = ""
                }
                generationProgress = 1.0
                
                // 转换为Event并保存（convertAndSavePlan 已经是 @MainActor，可以直接调用）
                if let plan = generatedPlan {
                    Task { @MainActor in
                        await convertAndSavePlan(plan)
                    }
                }
            }
        } catch {
            // 统一错误处理（只在这里处理一次）
            await MainActor.run {
                if !currentTask.isEmpty {
                    currentTask = ""
                }
                // 提供更友好的错误信息
                let friendlyMessage: String
                if error.localizedDescription.contains("超时") || error.localizedDescription.contains("timed out") || error.localizedDescription.contains("timeout") {
                    friendlyMessage = "生成行程超时。OpenAI API 响应时间过长，请检查网络连接或稍后重试。"
                } else if error.localizedDescription.contains("quota") || error.localizedDescription.contains("billing") {
                    friendlyMessage = "OpenAI API 配额已用完。请检查账户余额或使用其他 API Key。"
                } else {
                    friendlyMessage = "生成行程失败：\(error.localizedDescription)"
                }
                errorMessage = friendlyMessage
                showErrorAlert = true
                isGenerating = false
            }
        }
    }
    
    private func generateAIPoweredPlan(from result: ClassificationResult) async throws -> PlanResult {
        guard let destination = result.slots.destination.value else {
            throw PlanGenerationError.missingDestination
        }
        
        guard let dateRange = result.slots.dateRange.value else {
            throw PlanGenerationError.missingDateInfo
        }
        
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: dateRange.startDate, to: dateRange.endDate).day ?? 1
        let numberOfDays = max(1, days + 1)
        
        // 获取选中的周边特色名称
        let selectedAttractionNames = surroundingAttractions
            .filter { selectedSurroundingAttractions.contains($0.id) }
            .map { $0.name }
        
        let aiPlan = try await AITripGenerator.shared.generateAIItinerary(
            destination: destination,
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
            durationDays: numberOfDays,
            interestTags: result.slots.interestTags,
            pace: result.slots.pace.value ?? .moderate,
            walkingLevel: result.slots.walkingLevel.value,
            transportPreference: result.slots.transportPreference.value,
            selectedAttractions: selectedAttractionNames
        )
        
        var plan = try AITripGenerator.shared.convertToPlanResult(aiPlan, slots: result.slots)
        plan.assumptions = result.assumptions
        
        return plan
    }
    
    // 修复：去掉 MainActor 嵌套和 sleep，使用确定性顺序逻辑
    @MainActor
    private func convertAndSavePlan(_ plan: PlanResult) async {
        // 已经在 MainActor 上，不需要再包 MainActor.run
        isGenerating = false
        
        // 保存到模板
        savePlanToTemplate(plan, title: nil)
        
        // 更新 generatedPlan（确保数据一致性）
        generatedPlan = plan
        
        // 验证数据完整性后显示详情页（不需要 sleep，逻辑保证数据已准备好）
        if !plan.days.isEmpty {
            showPlanDetailView = true
        } else {
            // 如果数据无效，显示错误
            errorMessage = "生成的行程数据无效"
            showErrorAlert = true
        }
    }
    
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: calendar.component(.second, from: time),
            of: date
        ) ?? date
    }
    
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    // MARK: - 保存到模板
    private func savePlanToTemplate(_ plan: PlanResult, title: String?) {
        let userId = userManager.userOpenId
        
        // 生成默认标题或使用提供的标题
        // 优先使用用户填写的 tripTheme，其次使用传入的 title，最后使用默认标题
        let templateTitle: String
        if let customTitle = title, !customTitle.isEmpty {
            templateTitle = customTitle
        } else if !tripTheme.isEmpty {
            templateTitle = tripTheme
        } else if let destination = SavedTripTemplate.extractDestination(from: plan) {
            templateTitle = "\(destination) \(plan.days.count)天行程"
        } else {
            templateTitle = "行程模板 \(plan.days.count)天"
        }
        
        // 提取目的地
        let destination = SavedTripTemplate.extractDestination(from: plan)
        
        // 创建模板
        let template = SavedTripTemplate(
            title: templateTitle,
            plan: plan,
            savedDate: Date(),
            tags: [],
            destination: destination
        )
        
        // 保存模板
        TripTemplateManager.shared.saveTemplate(template, for: userId)
        
        print("✅ 行程已保存到模板：\(templateTitle)")
    }
}

// MARK: - 日期范围选择器
struct DateRangePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date?
    @Binding var isDateRange: Bool
    
    var body: some View {
        Form {
            Section {
                Toggle("多日行程", isOn: $isDateRange)
            }
            
            Section(header: Text("開始日期")) {
                DatePicker(
                    "開始日期",
                    selection: $startDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
            }
            
            if isDateRange {
                Section(header: Text("結束日期")) {
                    DatePicker(
                        "結束日期",
                        selection: Binding(
                            get: { endDate ?? startDate },
                            set: { endDate = $0 }
                        ),
                        in: startDate...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                }
            }
        }
        .onChange(of: isDateRange) { oldValue, newValue in
            if !newValue {
                endDate = nil
            } else if endDate == nil {
                let calendar = Calendar.current
                endDate = calendar.date(byAdding: .day, value: 2, to: startDate) ?? startDate
            }
        }
    }
}

// MARK: - 国家-城市选择器
struct CountryCityPickerView: View {
    @Binding var selectedCountry: String?
    @Binding var selectedCity: String?
    var onSelect: (String, String) -> Void
    
    @State private var searchText: String = ""
    @State private var selectedCountryIndex: Int? = nil
    
    // 示例数据：国家-城市映射
    private let countries: [String: [String]] = [
        "日本": ["東京", "京都", "大阪", "北海道", "沖繩", "福岡", "名古屋", "橫濱"],
        "台灣": ["台北", "台中", "高雄", "台南", "新北", "桃園", "新竹", "基隆"],
        "韓國": ["首爾", "釜山", "濟州島", "大邱", "仁川", "光州", "大田", "蔚山"],
        "中國": ["北京", "上海", "廣州", "深圳", "成都", "杭州", "西安", "重慶"],
        "泰國": ["曼谷", "清邁", "普吉島", "芭達雅", "華欣", "蘇梅島", "甲米", "清萊"],
        "新加坡": ["新加坡"],
        "馬來西亞": ["吉隆坡", "檳城", "蘭卡威", "沙巴", "馬六甲", "怡保", "新山", "古晉"],
        "越南": ["胡志明市", "河內", "峴港", "會安", "芽莊", "大叻", "順化", "下龍灣"],
        "印尼": ["雅加達", "峇里島", "日惹", "萬隆", "泗水", "棉蘭", "三寶壟", "龍目島"],
        "菲律賓": ["馬尼拉", "宿霧", "長灘島", "巴拉望", "薄荷島", "達沃", "碧瑤", "克拉克"]
    ]
    
    private var sortedCountries: [String] {
        Array(countries.keys).sorted()
    }
    
    private var filteredCountries: [String] {
        if searchText.isEmpty {
            return sortedCountries
        }
        return sortedCountries.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func cities(for country: String) -> [String] {
        return countries[country] ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜尋國家或城市...", text: $searchText)
            }
            .padding()
            .background(Color(.systemGray6))
            
            if let countryIndex = selectedCountryIndex, countryIndex < filteredCountries.count {
                // 显示城市列表
                let country = filteredCountries[countryIndex]
                List {
                    Section(header: Text("選擇城市 - \(country)")) {
                        ForEach(cities(for: country), id: \.self) { city in
                            Button(action: {
                                selectedCountry = country
                                selectedCity = city
                                onSelect(country, city)
                            }) {
                                HStack {
                                    Text(city)
                                    Spacer()
                                    if selectedCountry == country && selectedCity == city {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("返回") {
                            selectedCountryIndex = nil
                        }
                    }
                }
            } else {
                // 显示国家列表
                List {
                    ForEach(Array(filteredCountries.enumerated()), id: \.element) { index, country in
                        Button(action: {
                            selectedCountryIndex = index
                        }) {
                            HStack {
                                Text(country)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("步骤一：基本信息") {
    AIPlannerView()
        .environmentObject(MockFirebaseUserManager.shared)
}

#Preview("深色模式") {
    AIPlannerView()
        .environmentObject(MockFirebaseUserManager.shared)
        .preferredColorScheme(.dark)
}
