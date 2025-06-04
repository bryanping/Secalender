//  EditProfileView.swift
//  Secalender
//
//  Created by 林平 on 2025/6/5.
//

import SwiftUI
import Firebase
import Combine

struct EditProfileView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @State private var alias: String = ""
    @State private var displayName: String = ""
    @State private var gender: String = "Unknown"
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @State private var isAliasAvailable: Bool = true
    @State private var isCheckingAlias: Bool = false
    @State private var cancellable: AnyCancellable?

    var body: some View {
        Form {
            Section(header: Text("基本资料")) {
                TextField("别名（唯一）", text: $alias)
                    .onChange(of: alias) { newValue in
                        checkAliasAvailabilityDebounced(alias: newValue)
                    }

                if !isAliasAvailable {
                    Text("⚠️ 此别名已被使用")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                TextField("显示名称", text: $displayName)

                Picker("性别", selection: $gender) {
                    Text("男").tag("Male")
                    Text("女").tag("Female")
                    Text("未知").tag("Unknown")
                }
            }

            Button("保存资料") {
                Task {
                    await validateAndUpdateProfile()
                }
            }
            .disabled(!isAliasAvailable || alias.isEmpty)
        }
        .navigationTitle("编辑个人资料")
        .onAppear {
            alias = userManager.alias ?? ""
            displayName = userManager.displayName ?? ""
            gender = userManager.gender ?? "Unknown"
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("好") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func checkAliasAvailabilityDebounced(alias: String) {
        isCheckingAlias = true
        cancellable?.cancel()
        cancellable = Just(alias)
            .delay(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { value in
                Task {
                    self.isAliasAvailable = await userManager.checkAliasAvailable(alias: value)
                    self.isCheckingAlias = false
                }
            }
    }

    private func validateAndUpdateProfile() async {
        guard isAliasAvailable else {
            showErrorAlert = true
            errorMessage = "别名重复，请重新填写"
            return
        }

        let db = Firestore.firestore()
        let userId = userManager.userOpenId

        let data: [String: Any] = [
            "alias": alias,
            "display_name": displayName,
            "gender": gender
        ]

        do {
            try await db.collection("users").document(userId).updateData(data)
            userManager.refresh()
            dismiss()
        } catch {
            showErrorAlert = true
            errorMessage = "更新失败：\(error.localizedDescription)"
        }
    }
}
