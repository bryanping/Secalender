//
//  FriendsAndGroupsView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
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
    
    @State private var hasInitialized = false //修改内容：避免重复触发 loadData
    
    enum ManagementTab: Int, CaseIterable {
        case friends, groups
        
        var title: String {
            switch self {
            case .friends: return "朋友管理"
            case .groups: return "社群管理"
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
            .navigationTitle("朋友＆社群")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarButton
                }
            }
            .task {
                //修改内容：只在首次进入执行一次，避免 .onAppear + .task 重叠
                guard !hasInitialized else { return }
                hasInitialized = true
                await loadData()
            }
            .refreshable {
                await loadData()
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
    
    // MARK: - Toolbar Button
    @ViewBuilder
    private var toolbarButton: some View {
        Button {
            if selectedTab == .friends {
                showAddFriend = true
            } else {
                showAddGroup = true
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
        }
    }
    
    // MARK: - 朋友管理视图
    @ViewBuilder
    private var friendsView: some View {
        if isLoading {
            ProgressView("加载中...")
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
                Text("暂无好友")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("点击右上角 + 添加好友")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
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
    
    // MARK: - 社群管理视图
    @ViewBuilder
    private var groupsView: some View {
        if isLoading {
            ProgressView("加载中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        } else if groups.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "person.3")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray.opacity(0.6), .gray.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("暂无社群")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("点击右上角 + 创建社群")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(groups, id: \.id) { group in
                        GroupRowView(group: group)
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
    
    // MARK: - 数据加载
    private func loadData() async {
        await MainActor.run { self.isLoading = true } //修改内容：UI state 放主线程
        
        async let f: Void = loadFriends()
        async let g: Void = loadGroups()
        _ = await (f, g)
        
        await MainActor.run { self.isLoading = false } //修改内容：UI state 放主线程
    }
    
    private func loadFriends() async {
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("friends")
                .whereField("owner", isEqualTo: userManager.userOpenId)
                .getDocuments()
            
            let friendIds = snapshot.documents.compactMap { $0["friend"] as? String }
            print("📋 加载好友，找到 \(friendIds.count) 个好友ID")
            
            guard !friendIds.isEmpty else {
                await MainActor.run { self.friends = [] }
                return
            }
            
            //修改内容：批量用 documentID 查询 + 分批（避免 Firestore in 限制）
            let loadedFriends = try await fetchUsersByDocumentIds(db: db, userIds: friendIds)
            await MainActor.run {
                self.friends = loadedFriends
            }
        } catch {
            print("❌ 加载好友失败: \(error.localizedDescription)")
            await MainActor.run {
                self.friends = []
            }
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
    
    // MARK: - Helpers（批量取 user 文档，分批避免 in 限制）
    private func fetchUsersByDocumentIds(db: Firestore, userIds: [String]) async throws -> [FriendEntry] { //修改内容
        let chunks = userIds.chunked(into: 10)
        var results: [FriendEntry] = []
        results.reserveCapacity(userIds.count)
        
        try await withThrowingTaskGroup(of: [FriendEntry].self) { group in
            for chunk in chunks {
                group.addTask {
                    let snapshot = try await db.collection("users")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    
                    return snapshot.documents.compactMap { doc in
                        let data = doc.data()
                        return FriendEntry(
                            id: doc.documentID,
                            alias: data["alias"] as? String,
                            name: data["name"] as? String,
                            email: data["email"] as? String,
                            photoUrl: data["photo_url"] as? String,
                            gender: data["gender"] as? String
                        )
                    }
                }
            }
            
            for try await part in group {
                results.append(contentsOf: part)
            }
        }
        
        // 让排序稳定：按照原 friendIds 的顺序排列
        let order = Dictionary(uniqueKeysWithValues: userIds.enumerated().map { ($0.element, $0.offset) })
        results.sort { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
        return results
    }
}

// MARK: - 小工具：数组分批
private extension Array { //修改内容
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}


// MARK: - 朋友行视图
struct FriendRowView: View {
    let friend: FriendEntry
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 头像 - 玻璃态效果
            if let urlStr = friend.photoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
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
            
            // 信息
            VStack(alignment: .leading, spacing: 6) {
                Text(friend.alias ?? friend.email ?? friend.name ?? "未知好友")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let email = friend.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 删除按钮 - 玻璃态效果
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
        }
        .alert("删除好友", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await deleteFriend()
                }
            }
        } message: {
            Text("确定要删除这位好友吗？")
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
                    
                    Text("\(group.members.count) 位成员")
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
            // 頭像
            if let urlStr = member.photoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
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
                    Text(member.alias ?? member.email ?? member.name ?? "未知成员")
                        .font(.headline)
                    
                    if isMemberOwner {
                        Label("擁有者", systemImage: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else if isMemberAdmin {
                        Label("管理員", systemImage: "star.fill")
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
                                Label("取消管理員", systemImage: "star.slash")
                            }
                        } else {
                            Button(action: {
                                Task {
                                    await onSetAdmin(member.userId)
                                }
                            }) {
                                Label("設為管理員", systemImage: "star.fill")
                            }
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        Task {
                            await onRemoveMember(member.userId)
                        }
                    }) {
                        Label("移除成員", systemImage: "person.badge.minus")
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
            Section("管理員列表") {
                ForEach(members.filter { group.admins.contains($0.userId) }) { member in
                    HStack {
                        Text(member.alias ?? member.email ?? member.name ?? "未知")
                        Spacer()
                        if group.owner == member.userId {
                            Label("擁有者", systemImage: "crown.fill")
                                .foregroundColor(.orange)
                        } else {
                            Label("管理員", systemImage: "star.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section("普通成員") {
                ForEach(members.filter { !group.admins.contains($0.userId) && group.owner != $0.userId }) { member in
                    HStack {
                        Text(member.alias ?? member.email ?? member.name ?? "未知")
                        Spacer()
                        Button("設為管理員") {
                            Task {
                                await setAdmin(memberId: member.userId)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("管理員設置")
        .task {
            await loadMembers()
        }
    }
    
    private func loadMembers() async {
        isLoading = true
        do {
            members = try await GroupManager.shared.getGroupMembers(groupId: group.id ?? "")
        } catch {
            print("加載成員失敗：\(error.localizedDescription)")
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
            print("設置管理員失敗：\(error.localizedDescription)")
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
                    ProgressView("加載好友中...")
                } else if friends.isEmpty {
                    Text("暫無好友可邀請")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(friends, id: \.id) { friend in
                        HStack {
                            Text(friend.alias ?? friend.email ?? friend.name ?? "未知")
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
            .navigationTitle("邀請成員")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("邀請") {
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
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知錯誤")
            }
        }
    }
    
    private func loadFriends() async {
        isLoading = true
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("friends")
                .whereField("owner", isEqualTo: userManager.userOpenId)
                .getDocuments()
            
            let friendIds = snapshot.documents.compactMap { $0["friend"] as? String }
            
            if !friendIds.isEmpty {
                let userSnapshot = try await db.collection("users")
                    .whereField("user_id", in: friendIds)
                    .getDocuments()
                
                friends = userSnapshot.documents.compactMap { doc in
                    let data = doc.data()
                    return FriendEntry(
                        id: doc.documentID,
                        alias: data["alias"] as? String,
                        name: data["name"] as? String,
                        email: data["email"] as? String,
                        photoUrl: data["photo_url"] as? String,
                        gender: data["gender"] as? String
                    )
                }
            }
        } catch {
            errorMessage = "加載好友失敗：\(error.localizedDescription)"
            showErrorAlert = true
        }
        isLoading = false
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
