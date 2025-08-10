//
//  AddGroupView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/10.
//

import SwiftUI
import Firebase

struct AddGroupView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var groupName: String = ""
    @State private var groupDescription: String = ""
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            if userManager.userOpenId.isEmpty {
                ProgressView("加载中...").padding()
            } else {
                Text("建立社群")
                    .font(.title).bold()
                TextField("请输入社群名称", text: $groupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                TextField("社群描述（可选）", text: $groupDescription)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                Button("建立社群") {
                    Task { await createGroup() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(groupName.isEmpty || isLoading)
                .padding()

                if let message = errorMessage {
                    Text(message).foregroundColor(.red)
                }
                if showSuccessMessage {
                    Text("社群建立成功 ✅").foregroundColor(.green)
                }
            }
            Spacer()
        }
        .padding()
    }

    private func createGroup() async {
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
            try await db.collection("groups").addDocument(data: [
                "name": groupName,
                "description": groupDescription,
                "members": [userManager.userOpenId],
                "owner": userManager.userOpenId,
                "createdAt": Timestamp()
            ])
            showSuccessMessage = true
            groupName = ""
            groupDescription = ""
        } catch {
            errorMessage = "建立失败：\(error.localizedDescription)"
        }
        isLoading = false
    }
}
