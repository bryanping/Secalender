//
//  ReceivedFriendRequestsView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/25.
//

import SwiftUI
import FirebaseFirestore



struct ReceivedFriendRequestsView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var receivedRequests: [FriendRequest] = []

    var body: some View {
        List {
            Section(header: Text("收到的好友请求")) {
                if receivedRequests.isEmpty {
                    Text("暂无好友请求")
                        .foregroundColor(.gray)
                } else {
                    ForEach(receivedRequests) { request in
                        HStack {
                            Text(request.owner)
                            Spacer()
                            if request.status == "accepted" {
                                Text("已接受")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else {
                                Button("接受") {
                                    acceptRequest(id: request.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("好友请求")
        .onAppear {
            loadReceivedRequests()
        }
    }

    private func loadReceivedRequests() {
        let db = Firestore.firestore()
        db.collection("friendships")
            .whereField("friend", isEqualTo: userManager.userOpenId)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    self.receivedRequests = documents.compactMap { doc in
                        let data = doc.data()
                        guard let owner = data["owner"] as? String,
                              let status = data["status"] as? String else { return nil }
                        return FriendRequest(id: doc.documentID, friend: userManager.userOpenId, owner: owner, status: status)
                    }
                }
            }
    }

    private func acceptRequest(id: String) {
        let db = Firestore.firestore()
        db.collection("friendships").document(id).updateData([
            "status": "accepted"
        ]) { error in
            if error == nil {
                loadReceivedRequests()
            }
        }
    }
}

