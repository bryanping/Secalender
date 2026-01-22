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

enum PlannerTab {
    case aiPlanning      // AI 規劃
    case myTemplates     // 行程模板（保存的行程建议）
    case templateStore   // 模板市集（付费模板）
}

struct TravelTemplateView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    
    @State private var selectedTab: PlannerTab = .aiPlanning
    @State private var showAIPlanner = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 自定义Tab选择器
                CustomTabPicker(
                    tabs: [
                        ("AI 規劃", PlannerTab.aiPlanning),
                        ("行程模板", PlannerTab.myTemplates),
                        ("模板市集", PlannerTab.templateStore)
                    ],
                    selection: $selectedTab
                )
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
                
                // 内容区域
                Group {
                    switch selectedTab {
                    case .aiPlanning:
                        AIPlanningWelcomeView(showAIPlanner: $showAIPlanner)
                    case .myTemplates:
                        MyTemplatesView()
                            .environmentObject(userManager)
                    case .templateStore:
                        TemplateStoreView()
                    }
                }
            }
            .navigationTitle("智能規劃")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAIPlanner) {
                AIPlannerView()
                    .environmentObject(userManager)
            }
        }
    }
}
