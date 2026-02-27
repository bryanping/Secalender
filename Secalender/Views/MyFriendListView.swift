//
//  MyFriendListView.swift
//  Secalender
//
//  Created by 林平 on 2025/6/5.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct MyFriendListView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var friends: [FriendEntry] = []
    @State private var friendStats: [String: FriendCardStats] = [:]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(friends, id: \.id) { friend in
                    FriendCard(
                        friend: friend,
                        stats: friendStats[friend.id] ?? FriendCardStats(),
                        onViewProfile: { showFriendDetail(friend) },
                        onCompareAvailability: { showCompareSlots(friend) },
                        onInviteEvent: { showInviteEvent(friend) }
                    )
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("friends.my_friends".localized())
        .onAppear {
            loadMyFriends()
        }
    }

    private func showFriendDetail(_ friend: FriendEntry) {
        // 導航由 sheet 或 NavigationLink 處理，此處可擴展
    }

    private func showCompareSlots(_ friend: FriendEntry) {
        // 比對空檔：差異化功能，待實作
    }

    private func showInviteEvent(_ friend: FriendEntry) {
        // 邀請活動：已有流程，可導向 EventInvitationsView 或 InviteFriendsView
    }

    func loadMyFriends() {
        Task {
            // 使用 FriendManager 的缓存机制（参考微信做法）
            let loadedFriends = await FriendManager.shared.getFriends(for: userManager.userOpenId)
            await MainActor.run {
                self.friends = loadedFriends
            }
        }
    }
}

struct MyFriendListView_Previews: PreviewProvider {
    static var previews: some View {
        MyFriendListView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
