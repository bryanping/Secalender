//
//  AIPlanningWelcomeView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  AI规划欢迎页面
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AIPlanningWelcomeView: View {
    @Binding var showAIPlanner: Bool
    @EnvironmentObject var userManager: FirebaseUserManager
    @ObservedObject var themeManager = QuickThemeManager.shared
    /// 點擊主題卡片後帶預設進入統一 AIPlannerView（取代原 WeekendFlash / DeepCulture / EnrichTrip / TravelPlanning / 自訂主題 各自 sheet）
    @State private var showAIPlannerWithTheme: QuickTheme?
    @State private var showCreateTemplate = false
    @State private var showThemeManagement = false
    
    // 修改內容：統一入口 — 首頁一句話輸入與快捷場景
    @State private var quickInput = ""
    @FocusState private var isQuickInputFocused: Bool
    @State private var showQuickInputPlanner = false
    @State private var showTravelPlanner = false
    @State private var showTodayWorkspace = false
    // 修改內容：常用安排 — 按帳號載入；點擊沿用偏好進入對應流程
    @ObservedObject private var presetStore = PlanningPresetStore.shared
    @State private var presets: [PlanningPreset] = []
    @State private var activePreset: PlanningPreset? = nil

    @State private var searchText = ""
    @State private var selectedCategory: QuickThemeCategory = .all
    @State private var isSearchMode = false
    @FocusState private var isSearchFocused: Bool
    
    private var displayedThemes: [QuickTheme] {
        themeManager.themes(
            for: selectedCategory,
            searchText: searchText,
            userId: userManager.userOpenId
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer()
                    .frame(height: 8)
                    // 修改内容：Step4 — 進頁拉取雲端自訂主題（跨裝置同步）
                    .task {
                        await themeManager.syncFromCloud(userId: userManager.userOpenId)
                        // 修改內容：常用安排 — 按帳號載入（切換帳號不沿用）
                        presets = presetStore.load(userId: userManager.userOpenId)
                        await presetStore.syncFromCloud(userId: userManager.userOpenId)
                        presets = presetStore.load(userId: userManager.userOpenId)
                    }
                
                // 修改內容：統一入口 — 時間秘書首頁直接可操作：一句話輸入 ＋ 三個快捷場景；原大圓按鈕改為次要入口「更多」
                VStack(alignment: .leading, spacing: 14) {
                    Text("想安排什麼？")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)

                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        TextField("例：週六台北親子一日遊，下午五點前回家", text: $quickInput, axis: .vertical)
                            .lineLimit(1...3)
                            .focused($isQuickInputFocused)
                            .onSubmit { submitQuickInput() }
                        if !quickInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: submitQuickInput) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(14)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                    )

                    HStack(spacing: 10) {
                        quickSceneButton(title: "安排週末", icon: "sun.max.fill", color: .orange) {
                            quickInput = "安排這個週末"
                            submitQuickInput()
                        }
                        quickSceneButton(title: "規劃旅行", icon: "airplane", color: .blue) {
                            showTravelPlanner = true
                        }
                        quickSceneButton(title: "安排今天", icon: "checklist", color: .green) {
                            showTodayWorkspace = true
                        }
                    }

                    Button(action: { showAIPlanner = true }) {
                        HStack(spacing: 4) {
                            Text("更多安排方式")
                                .font(.system(size: 14))
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal)

                // 修改內容：常用安排 — 優先顯示最近真正套用過的設定
                if !presets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("我的常用安排")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal)
                        VStack(spacing: 10) {
                            ForEach(presets.prefix(5)) { p in
                                presetRow(p)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // 快速主题区域
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("welcome.quick_themes".localized())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            showThemeManagement = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 14))
                                Text("quick_theme.manage".localized())
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 分類標籤 + 搜索圖示
                    HStack(spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(QuickThemeCategory.allCases, id: \.self) { cat in
                                    Button {
                                        selectedCategory = cat
                                    } label: {
                                        Text(cat.localizedKey.localized())
                                            .font(.subheadline)
                                            .fontWeight(selectedCategory == cat ? .semibold : .regular)
                                            .foregroundColor(selectedCategory == cat ? .white : .primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(selectedCategory == cat ? Color.blue : Color(.systemGray6))
                                            .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isSearchMode = true
                                isSearchFocused = true
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .frame(width: 36, height: 36)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                    
                    // 搜索模式：點擊放大鏡後展開的搜索欄
                    if isSearchMode {
                        HStack(spacing: 10) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("quick_theme.search_placeholder".localized(), text: $searchText)
                                    .focused($isSearchFocused)
                            }
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            
                            Button(action: {
                                hideKeyboard()
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isSearchMode = false
                                    searchText = ""
                                    isSearchFocused = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // 主題卡片網格：每行三個，正方形帶圓角，參考圖片間距
                    // 修改內容：常用安排 — 新用戶第一張卡即可直接用；「新增」移到下方次要入口
                    let allItems: [(isAdd: Bool, theme: QuickTheme?)] = {
                        var items: [(Bool, QuickTheme?)] = []
                        items += displayedThemes.map { (false, $0) }
                        if selectedCategory == .custom { items.append((true, nil)) }
                        return items
                    }()
                    let columns = 3
                    let rowCount = (allItems.count + columns - 1) / columns
                    
                    VStack(spacing: 12) {
                        ForEach(0..<rowCount, id: \.self) { row in
                            HStack(spacing: 12) {
                                ForEach(0..<columns, id: \.self) { col in
                                    let index = row * columns + col
                                    if index < allItems.count {
                                        let item = allItems[index]
                                        Group {
                                            if item.isAdd {
                                                QuickThemeCardAdd(onTap: {
                                                    showCreateTemplate = true
                                                })
                                            } else if let theme = item.theme {
                                                QuickThemeCard(theme: theme, outcomeText: Self.outcomeText(for: theme)) {  // 修改內容：說清楚會幫我做什麼
                                                    handleThemeTap(theme)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        Color.clear
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 探索更多／新增主題（次要入口）
                    HStack(spacing: 20) {
                        Button(action: { showCreateTemplate = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                Text("新增主題")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        }
                        Button(action: {
                            showThemeManagement = true
                        }) {
                            HStack {
                                Text("quick_theme.explore_more".localized())
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                
                Spacer()
                    .frame(height: 100)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .background(Color(.systemGroupedBackground))
        .sheet(item: $showAIPlannerWithTheme) { theme in
            AIPlannerView(
                plannerModelType: plannerModelType(for: theme.key),
                themeKey: theme.key,
                customTheme: theme
            )
            .environmentObject(userManager)
        }
        .sheet(isPresented: $showCreateTemplate) {
            CreateTripTemplateView()
                .environmentObject(userManager)
        }
        .sheet(isPresented: $showThemeManagement) {
            QuickThemeManagementView()
                .environmentObject(userManager)
        }
        // 修改內容：統一入口 — 三種入口都走同一預覽（AIPlannerView / TravelPlannerContent / TodayWorkspaceView → PlanDetailView）
        .fullScreenCover(isPresented: $showQuickInputPlanner) {
            AIPlannerView(initialInput: quickInput, autoParse: true)
                .environmentObject(userManager)
        }
        .fullScreenCover(isPresented: $showTravelPlanner) {
            TravelPlannerContent()
                .environmentObject(userManager)
        }
        .fullScreenCover(isPresented: $showTodayWorkspace) {
            TodayWorkspaceView()
                .environmentObject(userManager)
        }
        // 修改內容：常用安排 — 沿用偏好進入對應流程；關閉後刷新列表
        .fullScreenCover(item: $activePreset, onDismiss: {
            presets = presetStore.load(userId: userManager.userOpenId)
        }) { p in
            presetDestination(p)
                .environmentObject(userManager)
        }
        .onReceive(presetStore.objectWillChange) { _ in
            DispatchQueue.main.async { presets = presetStore.load(userId: userManager.userOpenId) }
        }
        .onChange(of: userManager.userOpenId) { _, newId in
            presets = presetStore.load(userId: newId)  // 修改內容：更換帳號不沿用上一個帳號
        }
    }

    // MARK: - 修改內容：常用安排
    private func presetRow(_ p: PlanningPreset) -> some View {
        Button(action: {
            presetStore.markUsed(id: p.id, userId: userManager.userOpenId)
            activePreset = p
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: p.kind == .travel ? "airplane" : "star.fill")
                        .foregroundColor(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(p.summaryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                presetStore.delete(id: p.id, userId: userManager.userOpenId)
                presets = presetStore.load(userId: userManager.userOpenId)
            } label: { Label("刪除", systemImage: "trash") }
        }
    }

    /// 依保存來源決定流程；主題已不存在時退回旅遊／自由輸入（舊主題版本缺欄位亦不使流程失效）
    @ViewBuilder
    private func presetDestination(_ p: PlanningPreset) -> some View {
        let theme = p.themeKey.flatMap { key in themeManager.allThemes(userId: userManager.userOpenId).first { $0.key == key } }
        switch p.kind {
        case .travel:
            TravelPlannerContent(customTheme: theme, preset: p)
        case .themeForm:
            if let theme = theme {
                AIPlannerView(plannerModelType: .multiPhase, themeKey: theme.key, customTheme: theme, preset: p)
            } else {
                AIPlannerView(preset: p)
            }
        case .freeInput:
            AIPlannerView(preset: p)
        }
    }

    /// 內建主題卡片說明（使用者看到的是「會得到什麼」）
    static func outcomeText(for theme: QuickTheme) -> String {
        switch theme.key {
        case "weekend_flash": return "排一份半天或一天的出遊安排"
        case "deep_culture": return "按日期、區域組合文化行程"
        case "enrich_trip": return "用既有地點與空檔補上一段活動"
        case "travel_planning": return "產生可逐日查看的旅程"
        default:
            let s = theme.aiInstruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return s.isEmpty ? "依主題設定產生安排" : String(s.prefix(20))
        }
    }

    // 修改內容：統一入口 — 提交一句話（保留原句，關閉後可再改）
    private func submitQuickInput() {
        guard !quickInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isQuickInputFocused = false
        showQuickInputPlanner = true
    }

    private func quickSceneButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(UIColor.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// 依主題 key 回傳預設時間規劃型態（入口皆導向同一 AIPlannerView，僅預設不同）
    private func plannerModelType(for themeKey: String) -> PlannerModelType {
        switch themeKey {
        case "weekend_flash": return .multiPhase
        case "deep_culture", "enrich_trip", "travel_planning": return .multiPhase
        default: return .multiPhase
        }
    }
    
    private func handleThemeTap(_ theme: QuickTheme) {
        showAIPlannerWithTheme = theme
    }
}

// MARK: - 自定義主題入口卡片（虛線邊框，正方形帶圓角）
struct QuickThemeCardAdd: View {
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus.circle")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text("quick_theme.custom".localized())
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundColor(.gray.opacity(0.5))
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 快速主题卡片（正方形帶圓角，每行三個，圖標帶圓形底色）
struct QuickThemeCard: View {
    let theme: QuickTheme
    var outcomeText: String? = nil  // 修改內容：常用安排 — 卡片說明會幫我做什麼
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.iconColor.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: theme.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(theme.iconColor)
                }
                
                Text(theme.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                if let t = outcomeText {
                    Text(t)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


#Preview {
    AIPlanningWelcomeView(showAIPlanner: .constant(false))
        .environmentObject(MockFirebaseUserManager.shared)
}
