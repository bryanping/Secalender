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

    var body: some View {
        List {
            ForEach(friends, id: \.id) { friend in
                HStack(spacing: 12) {
                    if let urlStr = friend.photoUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                 .scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.alias ?? friend.email ?? friend.name ?? "friends.unknown".localized())
                            .font(.headline)
                        if let email = friend.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("friends.my_friends".localized())
        .onAppear {
            loadMyFriends()
        }
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
