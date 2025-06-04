//
//  GroupMemberSelectView.swift
//  Secalender
//
//  Created by 林平 on 2025/6/7.
//
//
//  GroupMemberSelectView.swift
//  Secalender
//
//  Created by 林平 on 2025/6/7.
//

import SwiftUI

struct GroupMemberSelectView: View {
    @Binding var selectedMemberIds: [String]
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @State private var allFriends: [FriendEntry] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(allFriends, id: \.id) { friend in
                    FriendRowView(
                        friend: friend,
                        isSelected: selectedMemberIds.contains(friend.id),
                        action: { toggleSelection(for: friend.id) }
                    )
                }
            }
            .navigationTitle("选择群成员")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: dismiss.callAsFunction)
                }
            }
            .task {
                await loadFriends()
            }
        }
    }

    private func toggleSelection(for id: String) {
        if selectedMemberIds.contains(id) {
            selectedMemberIds.removeAll { $0 == id }
        } else {
            selectedMemberIds.append(id)
        }
    }

    private func loadFriends() async {
        do {
            self.allFriends = try await userManager.fetchFriendDetails()
        } catch {
            self.allFriends = []
            print("加载好友失败: \(error.localizedDescription)")
        }
    }
}

