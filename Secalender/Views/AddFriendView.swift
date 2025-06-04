//
//  AddFriendView.swift
//  Secalender
//
//  Created by linping on 2024/7/1.
//

import SwiftUI
import Firebase

struct AddFriendView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var searchInput: String = ""
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            if userManager.userOpenId.isEmpty {
                ProgressView("加载中...") // 防止尚未登入完成就操作
                    .padding()
            } else {
                Text("添加好友")
                    .font(.title)
                    .bold()

                TextField("请输入对方的别名或邮箱", text: $searchInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button("添加好友") {
                    Task {
                        await searchAndAddFriend()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(searchInput.isEmpty || isLoading)
                .padding()

                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                }

                if showSuccessMessage {
                    Text("好友添加成功 ✅")
                        .foregroundColor(.green)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func searchAndAddFriend() async {
        errorMessage = nil
        showSuccessMessage = false
        isLoading = true

        guard !userManager.userOpenId.isEmpty else {
            errorMessage = "用户未登录，请稍后再试"
            isLoading = false
            return
        }

        do {
            let db = Firestore.firestore()
            var userIdToAdd: String?

            let aliasSnapshot = try await db.collection("users")
                .whereField("alias", isEqualTo: searchInput)
                .getDocuments()

            if let doc = aliasSnapshot.documents.first {
                userIdToAdd = doc.documentID
            }

            if userIdToAdd == nil {
                let emailSnapshot = try await db.collection("users")
                    .whereField("email", isEqualTo: searchInput)
                    .getDocuments()
                if let doc = emailSnapshot.documents.first {
                    userIdToAdd = doc.documentID
                }
            }

            guard let friendId = userIdToAdd else {
                errorMessage = "找不到该用户"
                isLoading = false
                return
            }

            if friendId == userManager.userOpenId {
                errorMessage = "无法添加自己为好友"
                isLoading = false
                return
            }

            // 檢查是否已添加過好友（可擴充）
            let existing = try await db.collection("friends")
                .whereField("owner", isEqualTo: userManager.userOpenId)
                .whereField("friend", isEqualTo: friendId)
                .getDocuments()
            if !existing.documents.isEmpty {
                errorMessage = "已经是好友"
                isLoading = false
                return
            }

            try await db.collection("friends").addDocument(data: [
                "owner": userManager.userOpenId,
                "friend": friendId,
                "createdAt": Timestamp()
            ])

            showSuccessMessage = true
            searchInput = ""
        } catch {
            errorMessage = "添加失败：\(error.localizedDescription)"
        }

        isLoading = false
    }
}


struct AddFriendView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
