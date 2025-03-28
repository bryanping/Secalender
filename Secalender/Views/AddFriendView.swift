//
//  AddFriendView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/22.
//

import SwiftUI
import Firebase

struct AddFriendView: View {
    @State private var newFriendEmail: String = ""
    @State private var currentUserOpenid: String = "current_user_openid" // 实际应从 Auth 获取
    @State private var showingSuccess = false

    var body: some View {
        Form {
            Section(header: Text("输入好友 Email")) {
                TextField("friend@example.com", text: $newFriendEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }

            Button("添加好友") {
                addFriend()
            }
        }
        .navigationTitle("添加好友")
        .alert(isPresented: $showingSuccess) {
            Alert(title: Text("成功"), message: Text("已发送好友邀请"), dismissButton: .default(Text("好")))
        }
    }

    private func addFriend() {
        guard !newFriendEmail.isEmpty else { return }
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "owner": currentUserOpenid,
            "friend": newFriendEmail
        ]
        db.collection("friendships").addDocument(data: data) { error in
            if error == nil {
                showingSuccess = true
                newFriendEmail = ""
            }
        }
    }
}


struct AddFriendView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendView()
    }
}
