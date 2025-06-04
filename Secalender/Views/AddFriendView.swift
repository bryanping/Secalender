//
//  AddFriendView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/22.
//

import SwiftUI
import Firebase
import FirebaseFirestore



struct AddFriendView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var newFriendEmail: String = ""
    @State private var showingSuccess = false
    @State private var friendRequests: [FriendRequest] = []

    var body: some View {
        Form {
            Section(header: Text("输入好友 Email")) {
                TextField("friend@example.com", text: $newFriendEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                Button("添加好友") {
                    addFriend()
                }
            }

            Section(header: Text("我添加的好友")) {
                if friendRequests.isEmpty {
                    Text("尚未添加任何好友")
                        .foregroundColor(.gray)
                } else {
                    ForEach(friendRequests) { request in
                        HStack {
                            Text(request.friend)
                            Spacer()
                            Text(request.status == "accepted" ? "已接受" : "待确认")
                                .foregroundColor(request.status == "accepted" ? .green : .orange)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("添加好友")
        .onAppear {
            loadFriendRequests()
        }
        .alert(isPresented: $showingSuccess) {
            Alert(title: Text("成功"), message: Text("已发送好友邀请"), dismissButton: .default(Text("好")))
        }
    }

    private func addFriend() {
        guard !newFriendEmail.isEmpty else { return }
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "owner": userManager.userOpenId,
            "friend": newFriendEmail,
            "status": "pending"
        ]
        db.collection("friendships").addDocument(data: data) { error in
            if error == nil {
                showingSuccess = true
                newFriendEmail = ""
                loadFriendRequests()
            }
        }
    }

    private func loadFriendRequests() {
        let db = Firestore.firestore()
        db.collection("friendships")
            .whereField("owner", isEqualTo: userManager.userOpenId)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    self.friendRequests = documents.compactMap { doc in
                        let data = doc.data()
                        guard let friend = data["friend"] as? String,
                              let status = data["status"] as? String else { return nil }
                        return FriendRequest(
                            id: doc.documentID,
                            friend: friend,
                            owner: userManager.userOpenId,
                            status: status
                        )
                    }
                }
            }
    }

}

struct FriendRequest: Identifiable {
    var id: String
    var friend: String
    var owner: String
    var status: String
}

struct AddFriendView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
