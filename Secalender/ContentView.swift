//
//  ContentView.swift
//  Secalender
//
//  Created by linping on 2024/6/12.
//

import SwiftUI

// MARK: - 中间按钮功能类型
enum MiddleButtonAction {
    case createEvent      // 建立行程
    case aiConversation   // AI对话
    case memberActions    // 成员功能（添加好友、创建社群、分享行程）
    
    var icon: String {
        switch self {
        case .createEvent:
            return "plus"
        case .aiConversation:
            return "message.fill"
        case .memberActions:
            return "ellipsis.circle.fill"
        }
    }
    
    static func action(for tab: Int) -> MiddleButtonAction {
        switch tab {
        case 1: return .createEvent      // CalendarView
        case 2: return .aiConversation   // TravelTemplateView
        case 3: return .memberActions    // FriendsAndGroupsView - 显示功能菜单
        case 4: return .createEvent      // MemberView - 建立行程
        default: return .createEvent
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var showCreateEvent = false
    @State private var showAIConversation = false
    @State private var showMemberActionSheet = false
    @State private var showFriendsActionSheet = false  // FriendsAndGroupsView 的功能菜单
    @State private var showAddFriend = false
    @State private var showAddGroup = false
    @EnvironmentObject var userManager: FirebaseUserManager
    
    // 中间按钮旋转动画状态
    @State private var iconRotation: Double = 0
    @State private var previousTab: Int = 1

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
                    middleButtonAction: MiddleButtonAction.action(for: selectedTab),
                    iconRotation: iconRotation,
                    onMiddleButtonTap: handleMiddleButtonTap
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onChange(of: selectedTab) { newTab in
            // 当切换页面时，添加旋转动画
            if newTab != previousTab {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    iconRotation += 360
                }
                previousTab = newTab
            }
        }
        .sheet(isPresented: $showCreateEvent) {
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
        .sheet(isPresented: $showAIConversation) {
            AIConversationView()
                .environmentObject(userManager)
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendView()
                .environmentObject(userManager)
        }
        .sheet(isPresented: $showAddGroup) {
            AddGroupView()
                .environmentObject(userManager)
        }
        .sheet(isPresented: $showFriendsActionSheet) {
            FriendsActionBottomSheet(
                onAddFriend: {
                    showFriendsActionSheet = false
                    showAddFriend = true
                },
                onAddGroup: {
                    showFriendsActionSheet = false
                    showAddGroup = true
                },
                onDismiss: {
                    showFriendsActionSheet = false
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
       
    }
    
    // MARK: - 中间按钮点击处理
    private func handleMiddleButtonTap() {
        let action = MiddleButtonAction.action(for: selectedTab)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            switch action {
            case .createEvent:
                showCreateEvent = true
            case .aiConversation:
                showAIConversation = true
            case .memberActions:
                // 根据当前 tab 显示不同的菜单
                if selectedTab == 3 {
                    // FriendsAndGroupsView - 显示添加好友、创建社群、分享行程菜单
                    showFriendsActionSheet = true
                } else {
                    // MemberView - 显示成员功能菜单（虽然现在不会到这里，因为 MemberView 是 createEvent）
                    showMemberActionSheet = true
                }
            }
        }
    }
}

// MARK: - 自定义TabBar组件
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let middleButtonAction: MiddleButtonAction
    let iconRotation: Double
    let onMiddleButtonTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Tab 1: 行事曆
            TabBarButton(
                icon: "calendar",
                label: "tab.calendar".localized(),
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            // Tab 2: 智能規劃
            TabBarButton(
                icon: "sparkles",
                label: "tab.ai_planning".localized(),
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
            
            // 中间的动态按钮 - 根据页面显示不同图标和功能
            Button(action: onMiddleButtonTap) {
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
                    
                    // 动态图标，带旋转动画和过渡效果
                    Image(systemName: middleButtonAction.icon)
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
                        .rotationEffect(.degrees(iconRotation))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: middleButtonAction.icon)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .offset(y: -22) // 轻微向上偏移
            .frame(maxWidth: .infinity)
            
            // Tab 3: 朋友＆社群
            TabBarButton(
                icon: "person.2.fill",
                label: "tab.friends_community".localized(),
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
            
            // Tab 4: 功能
            TabBarButton(
                icon: "gearshape",
                label: "tab.settings".localized(),
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

// MARK: - 底部弹出菜单组件
struct FriendsActionBottomSheet: View {
    let onAddFriend: () -> Void
    let onAddGroup: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 拖拽指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            // 标题
            Text("选择功能")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 20)
            
            // 功能按钮
            VStack(spacing: 12) {
                Button(action: onAddFriend) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("添加好友")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button(action: onAddGroup) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("创建社群")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.bottom, 20)
        .background(Color(UIColor.systemBackground))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
