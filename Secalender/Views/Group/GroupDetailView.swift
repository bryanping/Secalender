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
            Section(header: Text("group_detail.info".localized())) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("group_detail.name".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(group.name)
                        .font(.headline)
                }
                
                if !group.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("group_detail.description".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(group.description)
                            .font(.body)
                    }
                }
                
                HStack {
                    Text("group_detail.owner".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if isOwner {
                        Label("group_detail.you".localized(), systemImage: "crown.fill")
                            .foregroundColor(.orange)
                    } else {
                        Text("group_detail.members".localized())
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 成員列表
            Section(header: HStack {
                Text("group_detail.members_count".localized(with: group.members.count))
                Spacer()
                if canManage {
                    Button(action: { showInviteMembers = true }) {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.blue)
                    }
                }
            }) {
                if isLoadingMembers {
                    ProgressView("friends.loading".localized())
                } else if members.isEmpty {
                    Text("group_detail.no_member_info".localized())
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
                Section(header: Text("group_detail.management".localized())) {
                    if isOwner {
                        NavigationLink("group_detail.set_admin".localized()) {
                            AdminManagementView(group: $group, currentUserId: userManager.userOpenId)
                        }
                    }
                    NavigationLink("group_detail.group_activities".localized()) {
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
                            Text("group_detail.delete_group".localized())
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
                            Text("group_detail.leave_group".localized())
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
        .alert("group_detail.error".localized(), isPresented: $showErrorAlert) {
            Button("settings.ok".localized(), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "settings.error".localized())
        }
        .alert("group_detail.confirm_delete".localized(), isPresented: $showDeleteConfirmation) {
            Button("common.cancel".localized(), role: .cancel) {}
            Button("common.delete".localized(), role: .destructive) {
                Task {
                    await deleteGroup()
                }
            }
        } message: {
            Text("group_detail.delete_confirmation".localized())
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
