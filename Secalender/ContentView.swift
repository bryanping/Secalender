//
//  ContentView.swift
//  Secalender
//
//  Created by linping on 2024/6/12.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var showCreateEvent = false
    @EnvironmentObject var userManager: FirebaseUserManager

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域
            Group {
                switch selectedTab {
                case 1:
                    CalendarView()
                case 2:
                    TravelTemplateView()
                case 3:
                    FriendsAndGroupsView()
                case 4:
                    MemberView()
                default:
                    CalendarView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                // 为TabBar预留空间，防止内容被遮挡
                Spacer()
                    .frame(height: 80) // TabBar高度
            }
            
            // 自定义TabBar（固定在底部）
            VStack {
                Spacer()
                CustomTabBar(
                    selectedTab: $selectedTab,
                    onCreateTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            showCreateEvent = true
                        }
                    }
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showCreateEvent) {
            NavigationView {
                EventCreateView(
                    viewModel: EventDetailViewModel(
                        event: Event(
                            date: "",
                            startTime: "09:00:00",
                            endTime: "10:00:00",
                            createTime: ""
                        )
                    ),
                    onComplete: {
                        showCreateEvent = false
                    }
                )
                .environmentObject(userManager)
            }
        }
    }   
}

// MARK: - 自定义TabBar组件
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onCreateTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Tab 1: 行事曆
            TabBarButton(
                icon: "calendar",
                label: "行事曆",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            // Tab 2: 智能規劃
            TabBarButton(
                icon: "sparkles",
                label: "智能規劃",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
            
            // 中间的创建按钮 - 更柔和的设计
            Button(action: onCreateTap) {
                ZStack {
                    // 背景圆圈 - 使用更柔和的玻璃态效果
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.15),
                                            Color.blue.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: -1)
                    
                    // Plus图标
                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.9),
                                    Color.blue.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .offset(y: -22) // 轻微向上偏移
            .frame(maxWidth: .infinity)
            
            // Tab 3: 朋友＆社群
            TabBarButton(
                icon: "person.2.fill",
                label: "朋友＆社群",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
            
            // Tab 4: 功能
            TabBarButton(
                icon: "gearshape",
                label: "功能",
                isSelected: selectedTab == 4,
                action: { selectedTab = 4 }
            )
        }
        .frame(height: 100)
        .background(
            ZStack {
                // 玻璃态背景
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                // 顶部高光
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.15),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1)
                    
                    Spacer()
                        
                }
            }
        )
        .padding(.bottom, 0) // 确保TabBar紧贴底部
    }
}

// MARK: - TabBar按钮组件
struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .symbolVariant(isSelected ? .fill : .none)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 25)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
