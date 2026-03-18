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
            VStack(spacing: 40) {
                Spacer()
                    .frame(height: 5)
                
                // 中央图标区域
                VStack(spacing: 20) {
                    
                    Text("welcome.where_to_travel".localized())
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("welcome.create_perfect_itinerary".localized())
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Button(action: {
                        showAIPlanner = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.2),
                                            Color.blue.opacity(0.1),
                                            Color.clear
                                        ],
                                        startPoint: .center,
                                        endPoint: .init(x: 1.2, y: 1.2)
                                    )
                                )
                                .frame(width: 220, height: 220)
                                .blur(radius: 15)
                            
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 180, height: 180)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            VStack(spacing: 12) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .rotationEffect(.degrees(-45))
                                
                                Text("welcome.start_ai_planning".localized())
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
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
                    let allItems: [(isAdd: Bool, theme: QuickTheme?)] = {
                        var items: [(Bool, QuickTheme?)] = [(true, nil)]
                        items += displayedThemes.map { (false, $0) }
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
                                                QuickThemeCard(theme: theme) {
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
                    
                    // 探索更多
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
            }
            .padding(20)
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
