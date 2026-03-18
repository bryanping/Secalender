//
//  FriendsAndGroupsView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 朋友＆社群管理页面
struct FriendsAndGroupsView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var selectedTab: ManagementTab = .friends
    @State private var friends: [FriendEntry] = []
    @State private var groups: [CommunityGroup] = []
    @State private var isLoading = false
    @State private var showAddFriend = false
    @State private var showAddGroup = false
    @Namespace private var underlineNamespace
    
    @State private var hasInitialized = false
    @State private var activityInvitations: [NotificationEntry] = []
    @State private var feedRefreshTrigger = UUID()
    
    enum ManagementTab: Int, CaseIterable {
        case friends, groups
        
        @MainActor
        var title: String {
            switch self {
            case .friends: return "friends.management".localized()
            case .groups: return "groups.management".localized()
            }
        }
        
        var icon: String {
            switch self {
            case .friends: return "person.2.fill"
            case .groups: return "person.3.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                tabBarView
                contentView
            }

            .task {
                guard !hasInitialized else { return }
                hasInitialized = true
                // 與 MyFriendListView 一致：先顯示緩存本地數據
                let cached = FriendCacheManager.shared.loadFriends(for: userManager.userOpenId)
                if !cached.isEmpty {
                    self.friends = cached
                    self.isLoading = false
                }
                await loadData()
            }
            .refreshable {
                await MainActor.run { self.isLoading = true }
                let loadedFriends = await FriendManager.shared.getFriends(for: userManager.userOpenId, forceRefresh: true)
                await MainActor.run {
                    self.friends = loadedFriends
                    self.isLoading = false
                }
                await loadGroups()
                await loadActivityInvitations()
            }
            //修改内容：移除 onAppear 的重复加载，避免多次请求导致卡顿
            //.onAppear { Task { await loadData() } }
            .sheet(isPresented: $showAddFriend, onDismiss: {
                Task { await loadData() }
            }) {
                AddFriendView()
                    .environmentObject(userManager)
            }
            .sheet(isPresented: $showAddGroup, onDismiss: { //修改内容：新增社群后也刷新
                Task { await loadData() }
            }) {
                AddGroupView()
                    .environmentObject(userManager)
            }
        }
    }
    
    // MARK: - Tab Bar View
    @ViewBuilder
    private var tabBarView: some View {
        HStack(spacing: 0) {
            ForEach(ManagementTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .background(.ultraThinMaterial)
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
    private func tabButton(for tab: ManagementTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: .medium))
                    Text(tab.title)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(selectedTab == tab ? .primary : .secondary)
                .padding(.vertical, 12)
                
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
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if selectedTab == .friends {
            friendsView
        } else {
            groupsView
        }
    }
    
    // MARK: - 朋友管理视图
    @ViewBuilder
    private var friendsView: some View {
        if isLoading {
            ProgressView("friends.loading".localized())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        } else if friends.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "person.2")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.6), .gray.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("friends.no_friends".localized())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("friends.add_friend_hint".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if !activityInvitations.isEmpty {
                        FriendActivityCardStackView(
                            invitations: activityInvitations,
                            onRespond: { invitationId, status in
                                Task {
                                    await respondToActivityInvitation(invitationId: invitationId, status: status)
                                }
                            }
                        )
                        .environmentObject(userManager)
                    }
                    
                    ForEach(friends, id: \.id) { friend in
                        FriendRowView(friend: friend)
                            .glassCard(radius: 14, padding: 16)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 80)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func loadActivityInvitations() async {
        do {
            let all = try await EventManager.shared.fetchNotifications(for: userManager.userOpenId)
            let pending = all.filter { $0.type == "event_invitation" && $0.status == "pending" }
            await MainActor.run { self.activityInvitations = pending }
        } catch {
            await MainActor.run { self.activityInvitations = [] }
        }
    }
    
    private func respondToActivityInvitation(invitationId: String, status: String) async {
        do {
            try await EventManager.shared.respondToInvitation(notificationId: invitationId, status: status)
            await MainActor.run {
                activityInvitations.removeAll { $0.id == invitationId }
            }
        } catch {
            print("響應邀請失敗: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 社群管理视图（上半部：已關注的社群，下半部：最新公開行程、關注社群行程）
    @ViewBuilder
    private var groupsView: some View {
        if isLoading && groups.isEmpty {
            ProgressView("friends.loading".localized())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 上半部：已關注的社群（橫向滾動）
                    followedCommunitiesSection
                    
                    // 下半部：最新公開行程、關注社群行程
                    latestTripsSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await loadData()
                feedRefreshTrigger = UUID()
            }
        }
    }
    
    /// 上半部：已關注的社群（橫向滾動圓形圖標）
    @ViewBuilder
    private var followedCommunitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("groups.followed_communities".localized())
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            if groups.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.3")
                        .foregroundColor(.secondary)
                    Text("groups.no_groups".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(groups, id: \.id) { group in
                            NavigationLink(destination: GroupDetailView(group: group)) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.blue.opacity(0.4),
                                                        Color.blue.opacity(0.25)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                        Image(systemName: "person.3.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.blue, .blue.opacity(0.7)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 2)
                                    )
                                    
                                    Text(group.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .frame(width: 64)
                                }
                                .frame(width: 80)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground).opacity(0.5))
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 16)
    }
    
    /// 下半部：最新公開行程、關注社群行程
    @ViewBuilder
    private var latestTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("groups.latest_public_trips".localized())
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            CommunityTripsFeedView(
                groupIds: groups.compactMap { $0.id },
                friendIds: friends.map { $0.id },
                currentUserId: userManager.userOpenId,
                refreshTrigger: feedRefreshTrigger
            )
        }
    }
    
    // MARK: - 数据加载
    private func loadData() async {
        let hasCached = !FriendCacheManager.shared.loadFriends(for: userManager.userOpenId).isEmpty
        if !hasCached {
            await MainActor.run { self.isLoading = true }
        }
        
        async let f: Void = loadFriends()
        async let g: Void = loadGroups()
        async let a: Void = loadActivityInvitations()
        _ = await (f, g, a)
        
        await MainActor.run { self.isLoading = false }
    }
    
    private func loadFriends() async {
        // 與 MyFriendListView 一致：使用緩存機制，背景確認有無錯誤
        let loadedFriends = await FriendManager.shared.getFriends(for: userManager.userOpenId)
        await MainActor.run {
            self.friends = loadedFriends
        }
    }
    
    private func loadGroups() async {
        do {
            let list = try await GroupManager.shared.getUserGroups(userId: userManager.userOpenId)
            await MainActor.run { self.groups = list } //修改内容：UI state 放主线程
        } catch {
            print("加载社群失败: \(error.localizedDescription)")
            await MainActor.run { self.groups = [] } //修改内容
        }
    }
    
}


// MARK: - 朋友行视图（2.0：头像/人名、公开行程标签、分享活动/日历入口）
struct FriendRowView: View {
    let friend: FriendEntry
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showDeleteConfirmation = false
    @State private var showShareActivitySheet = false
    
    private var displayName: String {
        friend.alias ?? friend.name ?? friend.email ?? "friends.unknown".localized()
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 点击整行进入好友详情
            NavigationLink(destination: FriendDetailView(friendId: friend.id)
                .environmentObject(userManager)) {
                HStack(spacing: 16) {
                    // 頭像
                    if let urlStr = friend.photoUrl, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) {
                            Circle()
                                .fill(.ultraThinMaterial)
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 24))
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    
                    // 名字 + 可選公開行程標籤
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("friends.open_schedule".localized())
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.9), in: Capsule())
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            
            // 分享活動（不觸發導航）
            Button {
                showShareActivitySheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            
            // 日曆（進入好友詳情看行程）
            NavigationLink(destination: FriendDetailView(friendId: friend.id)
                .environmentObject(userManager)) {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            
            // 删除
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.red)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showShareActivitySheet) {
            ShareActivitiesToFriendSheet(
                friendId: friend.id,
                friendName: displayName
            )
            .environmentObject(userManager)
        }
        .alert("friends.delete".localized(), isPresented: $showDeleteConfirmation) {
            Button("common.cancel".localized(), role: .cancel) {}
            Button("common.delete".localized(), role: .destructive) {
                Task {
                    await deleteFriend()
                }
            }
        } message: {
            Text("friends.delete_confirmation".localized())
        }
    }
    
    private func deleteFriend() async {
        do {
            try await FriendManager.shared.removeFriend(
                currentUserId: userManager.userOpenId,
                targetUserId: friend.id
            )
        } catch {
            print("删除好友失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 分享活動給此好友（選擇行程後分享）
struct ShareActivitiesToFriendSheet: View {
    let friendId: String
    let friendName: String
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var events: [Event] = []
    @State private var selectedEventIds: Set<Int> = []
    @State private var isLoading = true
    @State private var isSharing = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("friends.loading".localized())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if events.isEmpty {
                    Text("friends.no_events_to_share".localized())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(events, id: \.id) { event in
                            if let eid = event.id {
                                Toggle(isOn: Binding(
                                    get: { selectedEventIds.contains(eid) },
                                    set: { if $0 { selectedEventIds.insert(eid) } else { selectedEventIds.remove(eid) } }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title)
                                            .font(.headline)
                                        if !event.date.isEmpty {
                                            Text(event.date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("event_share_action.share_event".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized()) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("event_share.share".localized()) {
                        Task { await shareSelected() }
                    }
                    .disabled(selectedEventIds.isEmpty || isSharing)
                }
            }
            .task {
                await loadMyEvents()
            }
            .alert("event_share_action.share_success".localized(), isPresented: $showSuccess) {
                Button("common.confirm".localized(), role: .cancel) {
                    dismiss()
                }
            }
        }
    }
    
    private func loadMyEvents() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await EventManager.shared.fetchEvents()
            let mine = all.filter { $0.creatorOpenid == userManager.userOpenId && ($0.deleted ?? 0) != 1 }
            await MainActor.run {
                events = mine.sorted { ($0.dateObj ?? .distantPast) < ($1.dateObj ?? .distantPast) }
            }
        } catch {
            await MainActor.run { events = [] }
        }
    }
    
    private func shareSelected() async {
        guard !selectedEventIds.isEmpty else { return }
        isSharing = true
        defer { isSharing = false }
        do {
            try await EventManager.shared.shareMultipleEventsWithFriends(
                eventIds: Array(selectedEventIds),
                friendIds: [friendId]
            )
            await MainActor.run { showSuccess = true }
        } catch {
            print("分享活動失敗: \(error.localizedDescription)")
        }
    }
}
// MARK: - 社群行视图
struct GroupRowView: View {
    let group: CommunityGroup
    @EnvironmentObject var userManager: FirebaseUserManager
    
    var body: some View {
        NavigationLink(destination: GroupDetailView(group: group)) {
            HStack(spacing: 16) {
                // 社群图标 - 玻璃态效果
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.3),
                                    Color.blue.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .fill(.ultraThinMaterial)
                    Image(systemName: "person.3.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: .blue.opacity(0.2), radius: 8, x: 0, y: 4)
                
                // 信息
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if !group.description.isEmpty {
                        Text(group.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text("groups.members_count".localized(with: group.members.count))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 朋友活動卡片預覽（滑動略過/參與）
struct FriendActivityCardStackView: View {
    let invitations: [NotificationEntry]
    let onRespond: (String, String) async -> Void
    
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var displayedInvitations: [NotificationEntry] = []
    @State private var cardOffsets: [String: CGFloat] = [:]
    @State private var cardRotations: [String: Double] = [:]
    private let swipeThreshold: CGFloat = 80
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle
            cardStack
        }
        .onAppear { displayedInvitations = invitations }
        .onChange(of: invitations) { _, newValue in displayedInvitations = newValue }
    }
    
    private var sectionTitle: some View {
        Text("朋友活動邀請")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding(.horizontal)
    }
    
    private var cardStack: some View {
        ZStack {
            ForEach(Array(displayedInvitations.enumerated().reversed()), id: \.element.id) { index, invitation in
                swipeableCard(invitation: invitation, index: index)
            }
        }
        .frame(height: 200)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func swipeableCard(invitation: NotificationEntry, index: Int) -> some View {
        FriendActivityCard(invitation: invitation)
            .environmentObject(userManager)
            .offset(x: cardOffsets[invitation.id] ?? 0)
            .rotationEffect(.degrees(cardRotations[invitation.id] ?? 0))
            .zIndex(Double(displayedInvitations.count - index))
            .gesture(dragGesture(for: invitation))
    }
    
    private func dragGesture(for invitation: NotificationEntry) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let dx = value.translation.width
                cardOffsets[invitation.id] = dx
                cardRotations[invitation.id] = Double(dx / 20)
            }
            .onEnded { value in
                handleSwipeEnd(for: invitation, translation: value.translation.width)
            }
    }
    
    private func handleSwipeEnd(for invitation: NotificationEntry, translation: CGFloat) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if translation > swipeThreshold {
                cardOffsets[invitation.id] = 500
                cardRotations[invitation.id] = 15
                Task { await performResponse(invitationId: invitation.id, status: "accepted") }
            } else if translation < -swipeThreshold {
                cardOffsets[invitation.id] = -500
                cardRotations[invitation.id] = -15
                Task { await performResponse(invitationId: invitation.id, status: "declined") }
            } else {
                cardOffsets[invitation.id] = 0
                cardRotations[invitation.id] = 0
            }
        }
    }
    
    private func performResponse(invitationId: String, status: String) async {
        try? await Task.sleep(nanoseconds: 200_000_000)
        await onRespond(invitationId, status)
        await MainActor.run {
            displayedInvitations.removeAll { $0.id == invitationId }
            cardOffsets[invitationId] = nil
            cardRotations[invitationId] = nil
        }
    }
}

struct FriendActivityCard: View {
    let invitation: NotificationEntry
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var event: Event?
    @State private var senderName: String = "好友"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(senderName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let e = event {
                        Text(e.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("\(e.date) \(e.startTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("活動邀請")
                            .font(.headline)
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                Spacer()
                HStack(spacing: 16) {
                    Text("略過")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("參與")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            if let e = event, !e.destination.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(e.destination)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        let e = await EventManager.shared.fetchEventForInvitation(eventId: invitation.eventId, creatorId: invitation.senderId)
        await MainActor.run { event = e }
        
        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(invitation.senderId)
                .getDocument()
            if let data = doc.data() {
                let name = (data["display_name"] as? String) ?? (data["alias"] as? String) ?? (data["name"] as? String) ?? (data["email"] as? String) ?? "好友"
                await MainActor.run { senderName = name }
            }
        } catch {
            print("載入發送者資訊失敗: \(error.localizedDescription)")
        }
    }
}

// MARK: - 成員行視圖
struct MemberRowView: View {
    let member: GroupMemberInfo
    let group: CommunityGroup
    let currentUserId: String
    let canManage: Bool
    let isOwner: Bool
    let onSetAdmin: (String) async -> Void
    let onRemoveAdmin: (String) async -> Void
    let onRemoveMember: (String) async -> Void
    
    var isCurrentUser: Bool {
        member.userId == currentUserId
    }
    
    var isMemberOwner: Bool {
        group.owner == member.userId
    }
    
    var isMemberAdmin: Bool {
        group.admins.contains(member.userId)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 頭像 - 優先本機快取
            if let urlStr = member.photoUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // 成員信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.alias ?? member.email ?? member.name ?? "groups.unknown_member".localized())
                        .font(.headline)
                    
                    if isMemberOwner {
                        Label("groups.owner".localized(), systemImage: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else if isMemberAdmin {
                        Label("groups.admin".localized(), systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                if let email = member.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // 操作按鈕（僅管理員可見，且不能操作自己）
            if canManage && !isCurrentUser && !isMemberOwner {
                Menu {
                    if isOwner {
                        if isMemberAdmin {
                            Button(role: .destructive, action: {
                                Task {
                                    await onRemoveAdmin(member.userId)
                                }
                            }) {
                                Label("groups.remove_admin".localized(), systemImage: "star.slash")
                            }
                        } else {
                            Button(action: {
                                Task {
                                    await onSetAdmin(member.userId)
                                }
                            }) {
                                Label("groups.set_admin".localized(), systemImage: "star.fill")
                            }
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        Task {
                            await onRemoveMember(member.userId)
                        }
                    }) {
                        Label("groups.remove_member".localized(), systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
} // MARK: - 管理員管理視圖
struct AdminManagementView: View {
    @Binding var group: CommunityGroup
    let currentUserId: String
    @State private var members: [GroupMemberInfo] = []
    @State private var isLoading = false
    
    var body: some View {
        List {
            Section("groups.admin_list".localized()) {
                ForEach(members.filter { group.admins.contains($0.userId) }) { member in
                    HStack {
                        Text(member.alias ?? member.email ?? member.name ?? "groups.unknown_member".localized())
                        Spacer()
                        if group.owner == member.userId {
                            Label("groups.owner".localized(), systemImage: "crown.fill")
                                .foregroundColor(.orange)
                        } else {
                            Label("groups.admin".localized(), systemImage: "star.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section("groups.regular_members".localized()) {
                ForEach(members.filter { !group.admins.contains($0.userId) && group.owner != $0.userId }) { member in
                    HStack {
                        Text(member.alias ?? member.email ?? member.name ?? "groups.unknown_member".localized())
                        Spacer()
                        Button("groups.set_admin".localized()) {
                            Task {
                                await setAdmin(memberId: member.userId)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("groups.admin_settings".localized())
        .task {
            await loadMembers()
        }
    }
    
    private func loadMembers() async {
        isLoading = true
        do {
            members = try await GroupManager.shared.getGroupMembers(groupId: group.id ?? "")
        } catch {
            print("groups.load_members_failed".localized(with: error.localizedDescription))
        }
        isLoading = false
    }
    
    private func setAdmin(memberId: String) async {
        guard let groupId = group.id else { return }
        do {
            try await GroupManager.shared.setAdmin(
                groupId: groupId,
                memberId: memberId,
                userId: currentUserId
            )
            group = try await GroupManager.shared.getGroup(groupId: groupId)
            await loadMembers()
        } catch {
            print("groups.set_admin_failed".localized(with: error.localizedDescription))
        }
    }
} // MARK: - 邀請成員視圖
struct InviteMembersToGroupView: View {
    let groupId: String
    let onInviteComplete: () -> Void
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var friends: [FriendEntry] = []
    @State private var selectedFriendIds: Set<String> = [] // 存儲 user_id
    @State private var isLoading = false
    @State private var isInviting = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView("groups.loading_friends".localized())
                } else if friends.isEmpty {
                    Text("groups.no_friends_to_invite".localized())
                        .foregroundColor(.secondary)
                } else {
                    ForEach(friends, id: \.id) { friend in
                        HStack {
                            Text(friend.alias ?? friend.email ?? friend.name ?? "friends.unknown".localized())
                            Spacer()
                            if selectedFriendIds.contains(friend.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFriendIds.contains(friend.id) {
                                selectedFriendIds.remove(friend.id)
                            } else {
                                selectedFriendIds.insert(friend.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("groups.invite_members".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized()) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("groups.invite".localized()) {
                        Task {
                            await inviteMembers()
                        }
                    }
                    .disabled(selectedFriendIds.isEmpty || isInviting)
                }
            }
            .task {
                await loadFriends()
            }
            .alert("settings.error".localized(), isPresented: $showErrorAlert) {
                Button("settings.ok".localized(), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "settings.error".localized())
            }
        }
    }
    
    private func loadFriends() async {
        isLoading = true
        // 使用 FriendManager 的缓存机制（参考微信做法）
        let loadedFriends = await FriendManager.shared.getFriends(for: userManager.userOpenId)
        await MainActor.run {
            self.friends = loadedFriends
            self.isLoading = false
        }
    }
    
    private func inviteMembers() async {
        isInviting = true
        do {
            let memberIds = Array(selectedFriendIds)
            try await GroupManager.shared.inviteMembers(
                groupId: groupId,
                memberIds: memberIds,
                userId: userManager.userOpenId
            )
            onInviteComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
        isInviting = false
    }
}

// MARK: - 頭像快取視圖（原 CachedAvatarView，合併於此）
/// 當前用戶頭像：優先使用本機儲存，沒有再用 URL
struct LocalUserAvatarView: View {
    let userId: String
    let remotePhotoUrl: String?
    let placeholder: () -> AnyView

    init(userId: String, remotePhotoUrl: String?, @ViewBuilder placeholder: @escaping () -> some View) {
        self.userId = userId
        self.remotePhotoUrl = remotePhotoUrl
        self.placeholder = { AnyView(placeholder()) }
    }

    var body: some View {
        if let data = LocalAvatarCache.loadAvatar(forUserId: userId),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let urlString = remotePhotoUrl, let url = URL(string: urlString) {
            CachedAsyncImage(url: url, placeholder: placeholder)
        } else {
            placeholder()
        }
    }
}

/// 依 URL 顯示圖片：先讀本機快取，沒有再從網路載入並寫入快取
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var loading = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if loading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            if let data = ImageCacheService.load(for: url), let ui = UIImage(data: data) {
                image = ui
                return
            }
            loading = true
            defer { loading = false }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let ui = UIImage(data: data) else {
                return
            }
            ImageCacheService.save(data, for: url)
            image = ui
        }
    }
}
