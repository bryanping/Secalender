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
    @Environment(\.dismiss) var dismiss
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

                TextField("请输入对方的别名、邮箱或用户ID", text: $searchInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button("发送好友请求") {
                    Task {
                        await searchAndSendRequest()
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
                    Text("好友请求已发送 ✅")
                        .foregroundColor(.green)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func searchAndSendRequest() async {
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

            // 首先尝试通过user_code（8位ID）搜索
            if !searchInput.isEmpty {
                let userCodeSnapshot = try await db.collection("users")
                    .whereField("user_code", isEqualTo: searchInput.uppercased())
                    .getDocuments()
                if let doc = userCodeSnapshot.documents.first {
                    userIdToAdd = doc.documentID
                }
            }

            // 如果还没找到，尝试通过user_id字段搜索
            if userIdToAdd == nil && !searchInput.isEmpty {
                // 尝试直接通过文档ID查找
                let userDocRef = db.collection("users").document(searchInput)
                let userDoc = try await userDocRef.getDocument()
                if userDoc.exists {
                    userIdToAdd = userDoc.documentID
                }
                
                // 如果文档ID不匹配，尝试通过user_id字段查找
                if userIdToAdd == nil {
                    let userIdSnapshot = try await db.collection("users")
                        .whereField("user_id", isEqualTo: searchInput)
                        .getDocuments()
                    if let doc = userIdSnapshot.documents.first {
                        userIdToAdd = doc.documentID
                    }
                }
            }

            // 如果还没找到，尝试通过别名搜索
            if userIdToAdd == nil {
                let aliasSnapshot = try await db.collection("users")
                    .whereField("alias", isEqualTo: searchInput)
                    .getDocuments()
                if let doc = aliasSnapshot.documents.first {
                    userIdToAdd = doc.documentID
                }
            }

            // 如果还没找到，尝试通过邮箱搜索
            if userIdToAdd == nil {
                let emailSnapshot = try await db.collection("users")
                    .whereField("email", isEqualTo: searchInput)
                    .getDocuments()
                if let doc = emailSnapshot.documents.first {
                    userIdToAdd = doc.documentID
                }
            }

            guard let targetUserId = userIdToAdd else {
                errorMessage = "找不到该用户，请检查别名、邮箱或用户ID是否正确"
                isLoading = false
                return
            }

            if targetUserId == userManager.userOpenId {
                errorMessage = "无法添加自己为好友"
                isLoading = false
                return
            }

            // 使用FriendManager发送好友请求
            try await FriendManager.shared.sendFriendRequest(
                from: userManager.userOpenId,
                to: targetUserId
            )

            showSuccessMessage = true
            searchInput = ""
            
            // 延迟关闭，让用户看到成功消息
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒
            dismiss()
        } catch {
            let nsError = error as NSError
            errorMessage = nsError.localizedDescription
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
