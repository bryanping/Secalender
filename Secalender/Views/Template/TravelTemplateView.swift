//
//  TravelTemplateView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  智能规划主页面，包含三个Tab：AI规划、行程模板、模板市集
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum PlannerTab: CaseIterable, Hashable {
    case aiPlanning
    case myTemplates
    case templateStore
    
    @MainActor
    var title: String {
        switch self {
        case .aiPlanning: return "tab.ai_planning".localized()
        case .myTemplates: return "tab.my_templates".localized()
        case .templateStore: return "tab.template_store".localized()
        }
    }
}

struct TravelTemplateView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    
    @State private var selectedTab: PlannerTab = .aiPlanning
    @State private var showAIPlanner = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @Namespace private var underlineNamespace
    
    private let allTabs = PlannerTab.allCases
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                tabBarView

                // 使用 GeometryReader 和 HStack 来实现平滑的页面切换
                GeometryReader { geometry in
        HStack(spacing: 0) {
                        ForEach(allTabs, id: \.self) { tab in
                            tabContentView(for: tab)
                                .frame(width: geometry.size.width)
                        }
                    }
                    .offset(x: -CGFloat(getCurrentTabIndex()) * geometry.size.width + dragOffset)
                    .animation(isDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onChanged { value in
                            // 只处理水平拖拽，限制垂直拖拽的影响
                            let horizontalMovement = abs(value.translation.width)
                            let verticalMovement = abs(value.translation.height)
                            
                            // 如果水平移动大于垂直移动，才认为是水平滑动
                            if horizontalMovement > verticalMovement {
                                isDragging = true
                                // 限制拖拽范围，避免拖拽太远
                                #if canImport(UIKit)
                                let screenWidth = UIScreen.main.bounds.width
                                #else
                                let screenWidth: CGFloat = 400
                                #endif
                                let maxOffset: CGFloat = screenWidth * 0.5
                                dragOffset = max(-maxOffset, min(maxOffset, value.translation.width))
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            let threshold: CGFloat = 80 // 拖拽阈值
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            
                            // 向右滑动（显示前一个 tab）
                            if value.translation.width > threshold || velocity > 400 {
                                switchToPreviousTab()
                            }
                            // 向左滑动（显示下一个 tab）
                            else if value.translation.width < -threshold || velocity < -400 {
                                switchToNextTab()
                            }
                            
                            // 重置偏移
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                )
                .onChange(of: selectedTab) { oldValue, newValue in
                    print("🟢 [TravelTemplateView] selectedTab: \(oldValue) -> \(newValue)")
                    // 重置偏移
                    dragOffset = 0
                            }
                        }

            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAIPlanner) {
                AIPlannerView()
                    .environmentObject(userManager)
            }
        }
    }

    // MARK: - Tab Bar View
    @ViewBuilder
    private var tabBarView: some View {
        HStack(spacing: 0) {
            ForEach(PlannerTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.1), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Tab Button
    @ViewBuilder
    private func tabButton(for tab: PlannerTab) -> some View {
        Button {
            //修改内容：不要用 withAnimation 包住 selectedTab，避免 List 在动画里重算卡死
            selectedTab = tab
        } label: {
            VStack(spacing: 8) {
                Text(tab.title)
                    .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    .padding(.vertical, 12)

                ZStack {
                    if selectedTab == tab {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.8),
                                        Color.blue.opacity(0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .matchedGeometryEffect(id: "underline", in: underlineNamespace)
                            .frame(height: 3)
                            .shadow(color: .blue.opacity(0.4), radius: 4, x: 0, y: 2)
                    } else {
                        Capsule()
                            .fill(Color.clear)
                            .frame(height: 3)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab) //修改内容：只动画底线
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab Content View
    
    @ViewBuilder
    private func tabContentView(for tab: PlannerTab) -> some View {
                Group {
            switch tab {
                    case .aiPlanning:
                        AIPlanningWelcomeView(showAIPlanner: $showAIPlanner)
                        
                    case .myTemplates:
                        MyTemplatesView()
                            .environmentObject(userManager)
                    .id("MyTemplatesView_\(tab.hashValue)")
                        
                    case .templateStore:
                        TemplateStoreView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    
    // MARK: - 辅助方法
    
    /// 获取当前 tab 的索引
    private func getCurrentTabIndex() -> Int {
        allTabs.firstIndex(of: selectedTab) ?? 0
    }
    
    // MARK: - 手势切换方法
    
    /// 切换到下一个 tab
    private func switchToNextTab() {
        guard let currentIndex = allTabs.firstIndex(of: selectedTab) else { return }
        
        let nextIndex = currentIndex + 1
        if nextIndex < allTabs.count {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = allTabs[nextIndex]
            }
        }
    }
    
    /// 切换到上一个 tab
    private func switchToPreviousTab() {
        guard let currentIndex = allTabs.firstIndex(of: selectedTab) else { return }
        
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = allTabs[previousIndex]
            }
        }
    }
}

// MARK: - Preview
// 修复：使用 FirebaseUserManager.shared（单例）进行预览
// 注意：预览可能需要 Firebase 初始化，如果预览失败，请确保 Firebase 已正确配置
#Preview("默认预览") {
    TravelTemplateView()
        .environmentObject(FirebaseUserManager.shared)
}

#Preview("深色模式") {
    TravelTemplateView()
        .environmentObject(FirebaseUserManager.shared)
        .preferredColorScheme(.dark)
}
