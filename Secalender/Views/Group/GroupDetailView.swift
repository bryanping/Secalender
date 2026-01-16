//
//  GroupDetailView.swift
//  Secalender
//
//  Created by 林平 on 2026/1/20.
//
// MARK: - 社群详情视图
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

struct GroupDetailView: View {
    @State var group: CommunityGroup
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var members: [GroupMemberInfo] = []
    @State private var isLoadingMembers = false
    @State private var showInviteMembers = false
    @State private var showMemberActions: String? = nil
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showDeleteConfirmation = false
    
    // 計算屬性：當前用戶的權限
    private var isOwner: Bool {
        group.isOwner(userId: userManager.userOpenId)
    }
    
    private var isAdmin: Bool {
        group.isAdmin(userId: userManager.userOpenId)
    }
    
    private var canManage: Bool {
        group.hasManagePermission(userId: userManager.userOpenId)
    }
    
    var body: some View {
        List {
            // 社群信息
            Section(header: Text("社群信息")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("名称")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(group.name)
                        .font(.headline)
                }
                
                if !group.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("描述")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(group.description)
                            .font(.body)
                    }
                }
                
                HStack {
                    Text("擁有者")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if isOwner {
                        Label("您", systemImage: "crown.fill")
                            .foregroundColor(.orange)
                    } else {
                        Text("成員")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 成員列表
            Section(header: HStack {
                Text("成员 (\(group.members.count))")
                Spacer()
                if canManage {
                    Button(action: { showInviteMembers = true }) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.blue)
                    }
                }
            }) {
                if isLoadingMembers {
                    ProgressView("加载成员中...")
                } else if members.isEmpty {
                    Text("暂无成员信息")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(members) { member in
                        MemberRowView(
                            member: member,
                            group: group,
                            currentUserId: userManager.userOpenId,
                            canManage: canManage,
                            isOwner: isOwner,
                            onSetAdmin: { memberId in
                                await setAdmin(memberId: memberId)
                            },
                            onRemoveAdmin: { memberId in
                                await removeAdmin(memberId: memberId)
                            },
                            onRemoveMember: { memberId in
                                await removeMember(memberId: memberId)
                            }
                        )
                    }
                }
            }
            
            // 管理操作
            if canManage {
                Section(header: Text("管理操作")) {
                    if isOwner {
                        NavigationLink("設置管理員") {
                            AdminManagementView(group: $group, currentUserId: userManager.userOpenId)
                        }
                    }
                    NavigationLink("社群活動") {
                        GroupEventsView(groupId: group.id ?? "")
                    }
                }
            }
            
            // 危險操作
            if isOwner {
                Section {
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("刪除社群")
                            Spacer()
                        }
                    }
                }
            } else {
                Section {
                    Button(role: .destructive, action: {
                        Task {
                            await leaveGroup()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("離開社群")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMembers()
        }
        .refreshable {
            await loadMembers()
        }
        .sheet(isPresented: $showInviteMembers) {
            InviteMembersToGroupView(groupId: group.id ?? "", onInviteComplete: {
                Task {
                    await refreshGroup()
                    await loadMembers()
                }
            })
        }
        .alert("錯誤", isPresented: $showErrorAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
        .alert("確認刪除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                Task {
                    await deleteGroup()
                }
            }
        } message: {
            Text("確定要刪除這個社群嗎？此操作無法撤銷。")
        }
    }
    
    // MARK: - 數據加載
    private func loadMembers() async {
        isLoadingMembers = true
        do {
            members = try await GroupManager.shared.getGroupMembers(groupId: group.id ?? "")
        } catch {
            errorMessage = "加載成員失敗：\(error.localizedDescription)"
            showErrorAlert = true
        }
        isLoadingMembers = false
    }
    
    private func refreshGroup() async {
        guard let groupId = group.id else { return }
        do {
            group = try await GroupManager.shared.getGroup(groupId: groupId)
        } catch {
            errorMessage = "刷新社群信息失敗：\(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    // MARK: - 成員管理
    private func setAdmin(memberId: String) async {
        guard let groupId = group.id else { return }
        do {
            try await GroupManager.shared.setAdmin(
                groupId: groupId,
                memberId: memberId,
                userId: userManager.userOpenId
            )
            await refreshGroup()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func removeAdmin(memberId: String) async {
        guard let groupId = group.id else { return }
        do {
            try await GroupManager.shared.removeAdmin(
                groupId: groupId,
                memberId: memberId,
                userId: userManager.userOpenId
            )
            await refreshGroup()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func removeMember(memberId: String) async {
        guard let groupId = group.id else { return }
        do {
            try await GroupManager.shared.removeMember(
                groupId: groupId,
                memberId: memberId,
                userId: userManager.userOpenId
            )
            await refreshGroup()
            await loadMembers()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func leaveGroup() async {
        guard let groupId = group.id else { return }
        do {
            try await GroupManager.shared.leaveGroup(
                groupId: groupId,
                userId: userManager.userOpenId
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func deleteGroup() async {
        guard let groupId = group.id else { return }
        do {
            try await GroupManager.shared.deleteGroup(
                groupId: groupId,
                userId: userManager.userOpenId
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
