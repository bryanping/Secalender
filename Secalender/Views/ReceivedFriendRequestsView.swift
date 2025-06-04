//
//  ReceivedFriendRequestsView.swift
//  Secalender
//
//  Created by linping on 2025/6/5.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct ReceivedFriendRequestsView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var requests: [QueryDocumentSnapshot] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载中...")
                } else if requests.isEmpty {
                    Text("暂无好友请求")
                        .foregroundColor(.gray)
                } else {
                    List {
                        ForEach(requests, id: \.documentID) { doc in
                            let data = doc.data()
                            let friendId = data["owner"] as? String ?? ""
                            HStack {
                                Text("请求来自: \(friendId.prefix(10))...")
                                Spacer()
                                Button("接受") {
                                    Task {
                                        await acceptRequest(from: friendId, requestDocId: doc.documentID)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }

                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            //.navigationTitle("好友请求")
            .onAppear {
                loadRequests()
            }
        }
    }

    private func loadRequests() {
        isLoading = true
        errorMessage = nil
        let db = Firestore.firestore()
        db.collection("friends")
            .whereField("friend", isEqualTo: userManager.userOpenId)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let docs = snapshot?.documents {
                        self.requests = docs
                    } else {
                        self.errorMessage = "加载失败"
                    }
                }
            }
    }

    private func acceptRequest(from senderId: String, requestDocId: String) async {
        let db = Firestore.firestore()

        do {
            // 添加对方为好友（双向）
            try await db.collection("friends").addDocument(data: [
                "owner": userManager.userOpenId,
                "friend": senderId,
                "createdAt": Timestamp()
            ])

            // 可选：更新已接受状态／删除请求
            try await db.collection("friends").document(requestDocId).delete()

            await MainActor.run {
                self.requests.removeAll { $0.documentID == requestDocId }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "接受失败：\(error.localizedDescription)"
            }
        }
    }
}
