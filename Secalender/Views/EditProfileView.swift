//  EditProfileView.swift
//  Secalender
//
//  Created by 林平 on 2025/6/5.
//

import SwiftUI
import FirebaseFirestore
import Combine

struct EditProfileView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            // MARK: - 基本资料
            Section(header: Text("profile.basic_info".localized())) {

                // 显示名称
                NavigationLink(destination: EditDisplayNameView().environmentObject(userManager)) {
                    HStack {
                        Text("profile.display_name".localized())
                        Spacer()
                        if let name = userManager.displayName, !name.isEmpty {
                            Text(name)
                                .foregroundColor(.secondary)
                        } else {
                            Text("profile.not_set".localized())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 用户ID
                NavigationLink(destination: EditUserCodeView().environmentObject(userManager)) {
                    HStack {
                        Text("profile.user_id".localized())
                        Spacer()
                        if let userCode = userManager.userCode {
                            Text(userCode)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            Text("profile.not_set".localized())
                                .foregroundColor(.secondary)
                        }
                        if userManager.userCodeModified {
                            Text("profile.modified".localized())
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                
                // 性别
                NavigationLink(destination: EditGenderView().environmentObject(userManager)) {
                    HStack {
                        Text("profile.gender".localized())
                        Spacer()
                        if let gender = userManager.gender, !gender.isEmpty {
                            Text(gender == "Male" ? "profile.male".localized() : (gender == "Female" ? "profile.female".localized() : "profile.unknown".localized()))
                                .foregroundColor(.secondary)
                        } else {
                            Text("profile.not_set".localized())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 手机号
                NavigationLink(destination: EditPhoneView().environmentObject(userManager)) {
                    HStack {
                        Text("profile.phone".localized())
                        Spacer()
                        if let phone = userManager.phone, !phone.isEmpty {
                            Text(phone)
                                .foregroundColor(.secondary)
                        } else {
                            Text("profile.not_set".localized())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 地区
                NavigationLink(destination: EditRegionView().environmentObject(userManager)) {
                    HStack {
                        Text("profile.region".localized())
                        Spacer()
                        if let region = userManager.region, !region.isEmpty {
                            Text(region)
                                .foregroundColor(.secondary)
                        } else {
                            Text("profile.not_set".localized())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 个性签名
                NavigationLink(destination: EditSignatureView().environmentObject(userManager)) {
                    HStack {
                        Text("profile.signature".localized())
                        Spacer()
                        if let signature = userManager.signature, !signature.isEmpty {
                            Text(signature)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("profile.not_set".localized())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // MARK: - 喜好标签
            Section(header: Text("profile.preferences".localized())) {
                NavigationLink(destination: EditFavoriteTagsView().environmentObject(userManager)) {
                    HStack {
                        Text("profile.favorite_tags".localized())
                        Spacer()
                        Text("profile.selected_tags".localized(with: userManager.favoriteTags.count))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("profile.edit_profile".localized())
    }
}

// MARK: - 编辑用户ID
struct EditUserCodeView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var userCode: String = ""
    @State private var isUserCodeAvailable: Bool = true
    @State private var isCheckingUserCode: Bool = false
    @State private var userCodeCancellable: AnyCancellable?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section {
                if userManager.userCodeModified {
                    HStack {
                        Text("profile.user_id".localized())
                        Spacer()
                        Text(userCode)
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                    Text("profile.modified_hint".localized())
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    TextField("profile.user_code_placeholder".localized(), text: $userCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .onChange(of: userCode) { oldValue, newValue in
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
                    
                    if isCheckingUserCode {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("profile.checking".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if !isUserCodeAvailable && userCode.count == 8 {
                        Text("profile.id_taken".localized())
                            .foregroundColor(.red)
                            .font(.caption)
                    } else if userCode.count == 8 {
                        Text("profile.id_available".localized())
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            } footer: {
                if !userManager.userCodeModified {
                    Text("profile.user_code_hint".localized())
                }
            }
        }
        .navigationTitle("profile.user_id".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized()) {
                    Task {
                        await saveUserCode()
                    }
                }
                .disabled(userManager.userCodeModified || userCode.count != 8 || !isUserCodeAvailable || userCode == (userManager.userCode ?? ""))
            }
        }
        .onAppear {
            userCode = userManager.userCode ?? ""
        }
        .alert("common.error".localized(), isPresented: $showErrorAlert) {
            Button("common.ok".localized()) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func checkUserCodeAvailabilityDebounced(userCode: String) {
        userCodeCancellable?.cancel()
        guard userCode != (userManager.userCode ?? "") else {
            isUserCodeAvailable = true
            return
        }
        isCheckingUserCode = true
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
        guard userCode != (userManager.userCode ?? "") else { return true }
        do {
            return try await UserManager.shared.isUserCodeUnique(userCode: userCode)
        } catch {
            return false
        }
    }
    
    private func saveUserCode() async {
        guard !userManager.userCodeModified else { return }
        guard isUserCodeAvailable && userCode.count == 8 else {
            errorMessage = "profile.id_invalid".localized()
            showErrorAlert = true
            return
        }
        
        do {
            try await UserManager.shared.updateUserCode(for: userManager.userOpenId, to: userCode)
            userManager.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - 编辑别名
struct EditAliasView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var alias: String = ""
    @State private var isAliasAvailable: Bool = true
    @State private var isCheckingAlias: Bool = false
    @State private var cancellable: AnyCancellable?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section {
                TextField("profile.alias_placeholder".localized(), text: $alias)
                    .onChange(of: alias) { oldValue, newValue in
                        checkAliasAvailabilityDebounced(alias: newValue)
                    }
                
                if isCheckingAlias {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("profile.checking".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !isAliasAvailable && !alias.isEmpty {
                    Text("profile.alias_taken".localized())
                        .foregroundColor(.red)
                        .font(.caption)
                }
            } footer: {
                Text("profile.alias_hint".localized())
            }
        }
        .navigationTitle("profile.alias".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized()) {
                    Task {
                        await saveAlias()
                    }
                }
                .disabled(!isAliasAvailable || alias.isEmpty || alias == (userManager.alias ?? ""))
            }
        }
        .onAppear {
            alias = userManager.alias ?? ""
        }
        .alert("common.error".localized(), isPresented: $showErrorAlert) {
            Button("common.ok".localized()) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func checkAliasAvailabilityDebounced(alias: String) {
        cancellable?.cancel()
        isCheckingAlias = true
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
        guard alias != (userManager.alias ?? "") else { return true }
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .whereField("alias", isEqualTo: alias)
                .getDocuments()
            return snapshot.documents.isEmpty
        } catch {
            return false
        }
    }
    
    private func saveAlias() async {
        guard isAliasAvailable else {
            errorMessage = "profile.alias_taken".localized()
            showErrorAlert = true
            return
        }
        
        do {
            try await UserManager.shared.updateAlias(for: userManager.userOpenId, to: alias)
            userManager.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - 编辑显示名称
struct EditDisplayNameView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section {
                TextField("profile.display_name_placeholder".localized(), text: $displayName)
            }
        }
        .navigationTitle("profile.display_name".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized()) {
                    Task {
                        await saveDisplayName()
                    }
                }
                .disabled(displayName == (userManager.displayName ?? ""))
            }
        }
        .onAppear {
            displayName = userManager.displayName ?? ""
        }
        .alert("common.error".localized(), isPresented: $showErrorAlert) {
            Button("common.ok".localized()) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveDisplayName() async {
        do {
            // 同时更新 name 和 display_name 字段，保持数据一致性
            try await Firestore.firestore().collection("users").document(userManager.userOpenId).updateData([
                "name": displayName,
                "display_name": displayName  // 兼容 Web 端或其他可能使用此字段的地方
            ])
            userManager.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - 编辑性别
struct EditGenderView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var gender: String = "Unknown"
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section {
                Picker("profile.gender".localized(), selection: $gender) {
                    Text("profile.male".localized()).tag("Male")
                    Text("profile.female".localized()).tag("Female")
                    Text("profile.unknown".localized()).tag("Unknown")
                }
            }
        }
        .navigationTitle("profile.gender".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized()) {
                    Task {
                        await saveGender()
                    }
                }
                .disabled(gender == (userManager.gender ?? "Unknown"))
            }
        }
        .onAppear {
            gender = userManager.gender ?? "Unknown"
        }
        .alert("common.error".localized(), isPresented: $showErrorAlert) {
            Button("common.ok".localized()) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveGender() async {
        do {
            try await Firestore.firestore().collection("users").document(userManager.userOpenId).updateData([
                "gender": gender
            ])
            userManager.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - 编辑手机号
struct EditPhoneView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var phone: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section {
                TextField("profile.phone_placeholder".localized(), text: $phone)
                    .keyboardType(.phonePad)
            }
        }
        .navigationTitle("profile.phone".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized()) {
                    Task {
                        await savePhone()
                    }
                }
                .disabled(phone == (userManager.phone ?? ""))
            }
        }
        .onAppear {
            phone = userManager.phone ?? ""
        }
        .alert("common.error".localized(), isPresented: $showErrorAlert) {
            Button("common.ok".localized()) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func savePhone() async {
        do {
            try await Firestore.firestore().collection("users").document(userManager.userOpenId).updateData([
                "phone": phone
            ])
            userManager.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - 编辑地区
struct EditRegionView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var region: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section {
                TextField("profile.region_placeholder".localized(), text: $region)
            }
        }
        .navigationTitle("profile.region".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized()) {
                    Task {
                        await saveRegion()
                    }
                }
                .disabled(region == (userManager.region ?? ""))
            }
        }
        .onAppear {
            region = userManager.region ?? ""
        }
        .alert("common.error".localized(), isPresented: $showErrorAlert) {
            Button("common.ok".localized()) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveRegion() async {
        do {
            try await Firestore.firestore().collection("users").document(userManager.userOpenId).updateData([
                "region": region
            ])
            userManager.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - 编辑个性签名
struct EditSignatureView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var signature: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section {
                TextField("profile.signature_placeholder".localized(), text: $signature, axis: .vertical)
                    .lineLimit(3...6)
            } footer: {
                Text("profile.signature_hint".localized())
            }
        }
        .navigationTitle("profile.signature".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized()) {
                    Task {
                        await saveSignature()
                    }
                }
                .disabled(signature == (userManager.signature ?? ""))
            }
        }
        .onAppear {
            signature = userManager.signature ?? ""
        }
        .alert("common.error".localized(), isPresented: $showErrorAlert) {
            Button("common.ok".localized()) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveSignature() async {
        do {
            try await Firestore.firestore().collection("users").document(userManager.userOpenId).updateData([
                "signature": signature
            ])
            userManager.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - 编辑喜好标签
struct EditFavoriteTagsView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTags: Set<String> = []
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section(header: HStack {
                Text("profile.preferences".localized())
                Spacer()
                Text("profile.selected_tags".localized(with: selectedTags.count))
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
        }
        .navigationTitle("profile.favorite_tags".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized()) {
                    Task {
                        await saveFavoriteTags()
                    }
                }
                .disabled(selectedTags.count > 6 || Array(selectedTags) == userManager.favoriteTags)
            }
        }
        .onAppear {
            selectedTags = Set(userManager.favoriteTags)
        }
        .alert("common.error".localized(), isPresented: $showErrorAlert) {
            Button("common.ok".localized()) {}
        } message: {
            Text(errorMessage)
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
    
    private func saveFavoriteTags() async {
        guard selectedTags.count <= 6 else {
            errorMessage = "profile.max_tags_exceeded".localized()
            showErrorAlert = true
            return
        }
        
        do {
            let tagsArray = Array(selectedTags)
            try await UserManager.shared.updateFavoriteTags(for: userManager.userOpenId, to: tagsArray)
            userManager.refresh()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
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
