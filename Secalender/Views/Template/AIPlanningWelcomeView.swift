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

// MARK: - 快速主题
struct QuickTheme {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
}

struct AIPlanningWelcomeView: View {
    @Binding var showAIPlanner: Bool
    
    // 快速主题列表
    private let quickThemes: [QuickTheme] = [
        QuickTheme(icon: "bolt.fill", iconColor: .orange, title: "週末快閃"),
        QuickTheme(icon: "building.columns.fill", iconColor: .purple, title: "深度文化"),
        QuickTheme(icon: "fork.knife", iconColor: .green, title: "美食探索")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Spacer()
                    .frame(height: 5)
                
                // 中央图标区域
                VStack(spacing: 20) {
                    // 大圆形图标（浅蓝色背景，三个星星）
                    ZStack {
                        // 星星图标
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    // 主标题
                    Text("想去哪裡旅行?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    // 副标题
                    Text("讓我為您打造完美的個人化行程")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    // "開始 AI 規劃" 按钮
                    Button(action: {
                        showAIPlanner = true
                    }) {
                        ZStack {
                            // 外圈光晕效果
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
                                .frame(width: 200, height: 200)
                                .blur(radius: 10)
                            
                            // 白色背景圆圈
                            Circle()
                                .fill(Color.white)
                                .frame(width: 180, height: 180)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            // 内容
                            VStack(spacing: 12) {
                                // 火箭图标
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .rotationEffect(.degrees(-45))
                                
                                // 文字
                                Text("開始 AI 規劃")
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
                        Text("快速主題")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            // TODO: 显示更多主题
                        }) {
                            Text("查看更多")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 主题卡片
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(quickThemes, id: \.id) { theme in
                                QuickThemeCard(theme: theme)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                    .frame(height: 100) // 为TabBar预留空间
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 快速主题卡片
struct QuickThemeCard: View {
    let theme: QuickTheme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: theme.icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(theme.iconColor)
            
            Text(theme.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .frame(width: 110, height: 110)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
