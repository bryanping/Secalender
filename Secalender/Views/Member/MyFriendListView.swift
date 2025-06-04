//
//  MyFriendListView.swift
//  Secalender
//
//  Created by 林平 on 2025/6/5.
//

import SwiftUI
import Firebase
import Foundation

struct MyFriendListView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var friends: [FriendEntry] = []

    var body: some View {
        List {
            ForEach(friends, id: \.id) { friend in
                VStack(alignment: .leading, spacing: 4) {
                    Text((friend.alias ?? friend.email ?? friend.name ?? "未知好友"))
                        .font(.headline)
                    if let email = friend.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("我的好友")
        .onAppear {
            loadMyFriends()
        }
    }

    func loadMyFriends() {
        let db = Firestore.firestore()
        db.collection("friendships")
            .whereField("owner", isEqualTo: userManager.userOpenId)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                let friendIds = docs.compactMap { $0["friend"] as? String }

                if !friendIds.isEmpty {
                    db.collection("users").whereField("user_id", in: friendIds).getDocuments { snap, err in
                        guard let documents = snap?.documents else { return }
                        self.friends = documents.compactMap { doc in
                            let data = doc.data()
                            return FriendEntry(
                                id: doc.documentID,
                                alias: data["alias"] as? String,
                                name: data["name"] as? String,
                                email: data["email"] as? String
                            )
                        }
                    }
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

