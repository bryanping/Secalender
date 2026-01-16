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
    @State private var phone: String = ""
    @State private var region: String = ""
    @State private var userCode: String = ""
    @State private var selectedTags: Set<String> = []  // 选中的喜好标签
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @State private var isAliasAvailable: Bool = true
    @State private var isCheckingAlias: Bool = false
    @State private var isUserCodeAvailable: Bool = true
    @State private var isCheckingUserCode: Bool = false
    @State private var cancellable: AnyCancellable?
    @State private var userCodeCancellable: AnyCancellable?

    var body: some View {
        Form {
            Section(header: Text("基本资料")) {
                // 用户ID（8位数字+大写字母）
                HStack {
                    Text("用户ID")
                    Spacer()
                    if userManager.userCodeModified {
                        Text(userCode)
                            .foregroundColor(.secondary)
                        Text("（已修改）")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        TextField("8位数字+大写字母", text: $userCode)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            .onChange(of: userCode) { oldValue, newValue in
                                // 只允许输入数字和大写字母，最多8位
                                let filtered = newValue.uppercased().filter { $0.isNumber || ($0.isLetter && $0.isUppercase) }
                                if filtered.count <= 8 {
                                    userCode = filtered
                                    if userCode.count == 8 {
                                        checkUserCodeAvailabilityDebounced(userCode: userCode)
                                    }
                                } else {
                                    userCode = String(filtered.prefix(8))
                                }
                            }
                    }
                }
                
                if !userManager.userCodeModified {
                    if isCheckingUserCode {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("检查中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if !isUserCodeAvailable && userCode.count == 8 {
                        Text("⚠️ 此ID已被使用")
                            .foregroundColor(.red)
                            .font(.caption)
                    } else if userCode.count == 8 {
                        Text("✓ ID可用")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                TextField("别名（唯一）", text: $alias)
                    .onChange(of: alias) { oldValue, newValue in
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
                
                TextField("手机号", text: $phone)
                    .keyboardType(.phonePad)
                
                TextField("地区", text: $region)
            }
            
            Section(header: HStack {
                Text("喜好标签")
                Spacer()
                Text("已选择 \(selectedTags.count)/6")
                    .font(.caption)
                    .foregroundColor(selectedTags.count > 6 ? .red : .secondary)
            }) {
                let availableTags = UserManager.getAvailableFavoriteTags()
                let columns = [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ]
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(availableTags, id: \.self) { tag in
                        TagButton(
                            tag: tag,
                            isSelected: selectedTags.contains(tag),
                            isDisabled: !selectedTags.contains(tag) && selectedTags.count >= 6
                        ) {
                            toggleTag(tag)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Button("保存资料") {
                Task {
                    await validateAndUpdateProfile()
                }
            }
            .disabled((!isAliasAvailable || alias.isEmpty) || (!userManager.userCodeModified && userCode.count == 8 && !isUserCodeAvailable) || selectedTags.count > 6)
        }
        .navigationTitle("编辑个人资料")
        .onAppear {
            alias = userManager.alias ?? ""
            displayName = userManager.displayName ?? ""
            gender = userManager.gender ?? "Unknown"
            phone = userManager.phone ?? ""
            region = userManager.region ?? ""
            userCode = userManager.userCode ?? ""
            selectedTags = Set(userManager.favoriteTags)
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("好") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func checkAliasAvailabilityDebounced(alias: String) {
        // 取消前一个请求
        cancellable?.cancel()

        isCheckingAlias = true

        // 延迟 0.5 秒触发请求，避免用户打字频繁触发
        cancellable = Just(alias)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { value in
                Task {
                    self.isAliasAvailable = await checkAliasAvailable(value)
                    self.isCheckingAlias = false
                }
            }
    }

    private func checkAliasAvailable(_ alias: String) async -> Bool {
        guard alias != (userManager.alias ?? "") else {
            return true // 原本就属自己的 alias，视为可用
        }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .whereField("alias", isEqualTo: alias)
                .getDocuments()
            return snapshot.documents.isEmpty
        } catch {
            print("检查 alias 出错：\(error.localizedDescription)")
            return false
        }
    }

    private func checkUserCodeAvailabilityDebounced(userCode: String) {
        // 取消前一个请求
        userCodeCancellable?.cancel()
        
        // 如果是自己的ID，视为可用
        guard userCode != (userManager.userCode ?? "") else {
            isUserCodeAvailable = true
            return
        }
        
        isCheckingUserCode = true
        
        // 延迟 0.5 秒触发请求
        userCodeCancellable = Just(userCode)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { value in
                Task {
                    self.isUserCodeAvailable = await checkUserCodeAvailable(value)
                    self.isCheckingUserCode = false
                }
            }
    }
    
    private func checkUserCodeAvailable(_ userCode: String) async -> Bool {
        guard userCode != (userManager.userCode ?? "") else {
            return true // 原本就属自己的ID，视为可用
        }
        
        do {
            return try await UserManager.shared.isUserCodeUnique(userCode: userCode)
        } catch {
            print("检查用户ID出错：\(error.localizedDescription)")
            return false
        }
    }

    private func validateAndUpdateProfile() async {
        guard isAliasAvailable else {
            errorMessage = "别名重复，无法保存"
            showErrorAlert = true
            return
        }
        
        // 如果用户修改了ID，检查ID是否可用
        if !userManager.userCodeModified && userCode != (userManager.userCode ?? "") {
            guard isUserCodeAvailable && userCode.count == 8 else {
                errorMessage = "用户ID不可用或格式不正确"
                showErrorAlert = true
                return
            }
        }

        let userId = userManager.userOpenId

        do {
            // 更新别名
            if alias != (userManager.alias ?? "") {
                try await UserManager.shared.updateAlias(for: userId, to: alias)
            }
            
            // 更新用户ID（如果修改了且未修改过）
            if !userManager.userCodeModified && userCode != (userManager.userCode ?? "") && userCode.count == 8 {
                try await UserManager.shared.updateUserCode(for: userId, to: userCode)
            }
            
            // 更新其他字段
            var updateData: [String: Any] = [
                "name": displayName,
                "gender": gender
            ]
            
            if phone != (userManager.phone ?? "") {
                updateData["phone"] = phone
            }
            
            if region != (userManager.region ?? "") {
                updateData["region"] = region
            }
            
            // 更新喜好标签
            let tagsArray = Array(selectedTags)
            if tagsArray != userManager.favoriteTags {
                try await UserManager.shared.updateFavoriteTags(for: userId, to: tagsArray)
            }
            
            // 批量更新
            try await Firestore.firestore().collection("users").document(userId).updateData(updateData)
            
            // 刷新用户数据
            userManager.refresh()
            dismiss()
        } catch {
            errorMessage = "更新失败：\(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            if selectedTags.count < 6 {
                selectedTags.insert(tag)
            }
        }
    }
}

// MARK: - 标签按钮组件
struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isSelected ? .white : (isDisabled ? .gray.opacity(0.5) : .primary))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
        }
        .disabled(isDisabled)
    }
}
