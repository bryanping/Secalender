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
                        ProgressView("加载中...").padding()
                    } else {
                        // 社群名称（必须）
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("社群名称")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("*")
                                    .foregroundColor(.red)
                            }
                            TextField("请输入社群名称", text: $groupName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // 社群描述（可选）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("社群简介（可选）")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("请输入社群简介", text: $groupDescription, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                        .padding(.horizontal)
                        
                        // 社群分类
                        VStack(alignment: .leading, spacing: 8) {
                            Text("社群分类")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("選擇分類", selection: $selectedCategory) {
                                Text("請選擇分類").tag("")
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
                            Text("地點（城市）")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("例如：台北、台中、高雄", text: $location)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // 關注權限
                        VStack(alignment: .leading, spacing: 12) {
                            Text("關注權限")
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
                        Button("建立社群") {
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
            .navigationTitle("建立社群")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("建立成功", isPresented: $showSuccessAlert) {
                Button("確定") {
                    dismiss()
                }
            } message: {
                Text("社群建立成功！")
            }
        }
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
        
        guard !groupName.isEmpty else {
            errorMessage = "請輸入社群名稱"
            isLoading = false
            return
        }
        
        guard !selectedCategory.isEmpty else {
            errorMessage = "請選擇社群分類"
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
            errorMessage = "建立失败：\(error.localizedDescription)"
        }
        isLoading = false
    }
}
