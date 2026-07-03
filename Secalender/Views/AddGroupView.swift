//
//  AddGroupView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/10.
//

import SwiftUI
import Firebase

/// 社群分類選項
let GROUP_CATEGORIES = [
    "運動健身", "旅遊休閒", "美食餐飲", "音樂藝術", "讀書學習",
    "科技數位", "寵物飼養", "親子育兒", "攝影寫真", "遊戲娛樂",
    "商業創業", "志工服務", "宗教心靈", "語言交流", "其他"
]

struct AddGroupView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var groupName: String = ""
    @State private var groupDescription: String = ""
    @State private var selectedCategory: String = ""
    @State private var location: String = ""
    @State private var selectedPrivacy: GroupPrivacy = .public
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    @State private var isLoading = false
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if userManager.userOpenId.isEmpty {
                        ProgressView("friends.loading".localized()).padding()
                    } else {
                        // 社群名称（必须）
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("add_group.name".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("*")
                                    .foregroundColor(.red)
                            }
                            TextField("add_group.name_placeholder".localized(), text: $groupName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // 社群描述（可选）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("add_group.description".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("add_group.description_placeholder".localized(), text: $groupDescription, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                        .padding(.horizontal)
                        
                        // 社群分类
                        VStack(alignment: .leading, spacing: 8) {
                            Text("add_group.category".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("add_group.select_category".localized(), selection: $selectedCategory) {
                                Text("add_group.select_category".localized()).tag("")
                                ForEach(GROUP_CATEGORIES, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        // 地点（城市）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("add_group.location".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("add_group.location_placeholder".localized(), text: $location)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // 關注權限
                        VStack(alignment: .leading, spacing: 12) {
                            Text("add_group.privacy".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ForEach(GroupPrivacy.allCases, id: \.self) { privacy in
                                Button {
                                    selectedPrivacy = privacy
                                } label: {
                                    HStack {
                                        Image(systemName: selectedPrivacy == privacy ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedPrivacy == privacy ? .blue : .gray)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(privacy.displayName)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(privacy.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(selectedPrivacy == privacy ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 建立按钮
                        Button("add_group.create".localized()) {
                            Task { await createGroup() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(groupName.isEmpty || selectedCategory.isEmpty || isLoading)
                        .padding()

                        if let message = errorMessage {
                            Text(message)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("add_group.title".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized()) {
                        dismiss()
                    }
                }
            }
            .alert("add_group.create_success".localized(), isPresented: $showSuccessAlert) {
                Button("settings.ok".localized()) {
                    dismiss()
                }
            } message: {
                Text("add_group.create_success".localized())
            }
        }
    }

    private func createGroup() async {
        errorMessage = nil
        showSuccessMessage = false
        isLoading = true

        guard !userManager.userOpenId.isEmpty else {
            errorMessage = "add_friend.user_not_logged_in".localized()
            isLoading = false
            return
        }
        
        guard !groupName.isEmpty else {
            errorMessage = "add_group.name_required".localized()
            isLoading = false
            return
        }
        
        guard !selectedCategory.isEmpty else {
            errorMessage = "add_group.category_required".localized()
            isLoading = false
            return
        }
        
        // 檢查手機號是否已驗證
        do {
            let isVerified = try await UserManager.shared.isPhoneVerified(userId: userManager.userOpenId)
            if !isVerified {
                errorMessage = "創建社群需要先驗證手機號碼，請前往個人資料完成驗證"
                isLoading = false
                return
            }
        } catch {
            errorMessage = "檢查驗證狀態失敗：\(error.localizedDescription)"
            isLoading = false
            return
        }
        
        do {
            _ = try await GroupManager.shared.createGroup(
                name: groupName,
                description: groupDescription,
                category: selectedCategory,
                location: location.isEmpty ? nil : location,
                privacy: selectedPrivacy,
                ownerId: userManager.userOpenId
            )
            showSuccessMessage = true
            groupName = ""
            groupDescription = ""
            selectedCategory = ""
            location = ""
            selectedPrivacy = .public
            
            // 顯示成功提示，然後自動返回
            showSuccessAlert = true
        } catch {
            errorMessage = "add_group.create_failed_prefix".localized(with: error.localizedDescription)
        }
        isLoading = false
    }
}
