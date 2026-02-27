//  EditProfileView.swift
//  Secalender
//
//  Created by 林平 on 2025/6/5.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var linkedProviders: Set<String> = []
    @State private var isLinkingProvider = false
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - 頭像區
                avatarSection
                
                // MARK: - 基本資料
                basicInfoSection
                
                // MARK: - 綁定社交帳號
                bindSocialSection
                
                // MARK: - 喜好標籤
                preferencesSection
            }
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("profile.edit_profile".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("profile.save".localized()) {
                    hideKeyboard()
                    dismiss()
                }
                .fontWeight(.medium)
            }
        }
        .onAppear {
            loadLinkedProviders()
        }
        .alert("common.error".localized(), isPresented: $showErrorAlert) {
            Button("common.ok".localized()) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareProfileSheetView(userName: userManager.displayName ?? "", userCode: userManager.userCode ?? "")
        }
    }
    
    // MARK: - 頭像區
    private var avatarSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack(alignment: .bottomTrailing) {
                    avatarImage
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    
                    if isUploadingAvatar {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .overlay(ProgressView().tint(.white))
                            .frame(width: 100, height: 100)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.blue))
                            .offset(x: 4, y: 4)
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task { await uploadSelectedPhoto(newItem) }
            }
            .disabled(isUploadingAvatar)
            
            Text("profile.change_avatar_hint".localized())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var avatarImage: some View {
        if let photoUrl = userManager.photoUrl, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.8))
            )
    }
    
    // MARK: - 基本資料
    private var basicInfoSection: some View {
        VStack(spacing: 0) {
            profileRow(
                label: "profile.display_name".localized(),
                value: userManager.displayName ?? "profile.not_set".localized(),
                icon: "person",
                destination: AnyView(EditDisplayNameView().environmentObject(userManager))
            )
            
            profileRow(
                label: "profile.user_id".localized(),
                value: (userManager.userCode ?? "profile.not_set".localized()) + (userManager.userCodeModified ? " profile.modified".localized() : ""),
                icon: "lock.fill",
                isMonospaced: true,
                destination: AnyView(EditUserCodeView().environmentObject(userManager))
            )
            
            profileRow(
                label: "profile.gender".localized(),
                value: genderDisplayText,
                icon: "person.fill.questionmark",
                destination: AnyView(EditGenderView().environmentObject(userManager))
            )
            
            profileRow(
                label: "profile.region".localized(),
                value: userManager.region ?? "profile.not_set".localized(),
                icon: "location.fill",
                destination: AnyView(EditRegionView().environmentObject(userManager))
            )
            
            profileRow(
                label: "profile.signature".localized(),
                value: userManager.signature ?? "profile.not_set".localized(),
                icon: "signature",
                lineLimit: 2,
                destination: AnyView(EditSignatureView().environmentObject(userManager))
            )
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var genderDisplayText: String {
        guard let g = userManager.gender, !g.isEmpty else { return "profile.not_set".localized() }
        switch g {
        case "Male": return "profile.male".localized()
        case "Female": return "profile.female".localized()
        default: return "profile.unknown".localized()
        }
    }
    
    @ViewBuilder
    private func profileRow(
        label: String,
        value: String,
        icon: String,
        isMonospaced: Bool = false,
        lineLimit: Int = 1,
        destination: AnyView
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .center)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                        .foregroundColor(.primary)
                        .lineLimit(lineLimit)
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 綁定社交帳號
    private var bindSocialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.bind_social_accounts".localized())
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            VStack(spacing: 0) {
                socialAccountRow(
                    id: "google.com",
                    name: "Google",
                    iconName: "GoogleLogo",
                    systemIcon: "g.circle.fill"
                )
                socialAccountRow(
                    id: "apple.com",
                    name: "Apple",
                    iconName: nil,
                    systemIcon: "apple.logo"
                )
                socialAccountRow(
                    id: "instagram",
                    name: "Instagram",
                    iconName: nil,
                    systemIcon: "camera.fill",
                    isExternal: true
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }
    
    private func socialAccountRow(
        id: String,
        name: String,
        iconName: String?,
        systemIcon: String,
        isExternal: Bool = false
    ) -> some View {
        let isBound = linkedProviders.contains(id)
        let showQuickShare = (id == "google.com" || id == "apple.com") && isBound
        
        return Button {
            if isExternal && id == "instagram" {
                if let url = URL(string: "https://www.instagram.com/") {
                    UIApplication.shared.open(url)
                }
            } else if showQuickShare {
                showShareSheet = true
            } else if !isBound {
                Task { await linkProvider(id: id) }
            }
        } label: {
            HStack(spacing: 12) {
                if let iconName = iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: systemIcon)
                        .font(.title2)
                        .foregroundColor(id == "apple.com" ? .primary : .blue)
                        .frame(width: 28, height: 28)
                }
                
                Text(name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isExternal && id == "instagram" {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabel))
                } else if showQuickShare {
                    HStack(spacing: 4) {
                        Text("profile.quick_share".localized())
                            .font(.caption)
                            .foregroundColor(.blue)
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } else {
                    Text(isBound ? "profile.bound".localized() : "profile.unbound".localized())
                        .font(.caption)
                        .foregroundColor(isBound ? .green : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .disabled(isLinkingProvider)
    }
    
    // MARK: - 喜好標籤
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.preferences".localized())
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            NavigationLink(destination: EditFavoriteTagsView().environmentObject(userManager)) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.secondary)
                    Text("profile.favorite_tags".localized())
                    Spacer()
                    Text("profile.selected_tags".localized(with: userManager.favoriteTags.count))
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }
    
    // MARK: - Actions
    private func loadLinkedProviders() {
        do {
            let providers = try AuthenticationManager.shared.getProviders()
            linkedProviders = Set(providers.map { $0.rawValue })
        } catch {
            linkedProviders = []
        }
    }
    
    private func uploadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item,
              let imageData = try? await item.loadTransferable(type: Data.self) else { return }
        
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        
        do {
            let urlString = try await AvatarUploadService.uploadAvatar(imageData: imageData, userId: userManager.userOpenId)
            try await UserManager.shared.updatePhotoUrl(for: userManager.userOpenId, to: urlString)
            userManager.refresh()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private func linkProvider(id: String) async {
        isLinkingProvider = true
        defer { isLinkingProvider = false }
        
        do {
            if id == "google.com" {
                let helper = SignInGoogleHelper()
                let tokens = try await helper.signIn()
                _ = try await AuthenticationManager.shared.linkGoogle(tokens: tokens)
                try await UserManager.shared.createNewUser(auth: try AuthenticationManager.shared.getAuthenticatedUser(), providerName: tokens.name, providerType: "google")
            } else if id == "apple.com" {
                let helper = SignInAppleHelper()
                let tokens = try await helper.startSignInWithAppleFlow()
                _ = try await AuthenticationManager.shared.linkApple(tokens: tokens)
                try await UserManager.shared.createNewUser(auth: try AuthenticationManager.shared.getAuthenticatedUser(), providerName: tokens.name, providerType: "apple")
            }
            userManager.refresh()
            loadLinkedProviders()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
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
