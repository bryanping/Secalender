//
//  SettingsView.swift
//  Secalender
//
//  系統設定：對齊 個人檔案頁面管理結構.md
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("darkModePreference") private var darkModePreference = "system" // system | light | dark
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Binding var showSignInView: Bool
    @StateObject private var userManager = FirebaseUserManager.shared
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var showLogoutConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var cacheInfo: (exists: Bool, size: Int64, lastModified: Date?) = (false, 0, nil)

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    var body: some View {
        List {
            // MARK: - 帳號與安全
            Section {
                NavigationLink(destination: EditProfileView().environmentObject(userManager)) {
                    settingsRow(icon: "person.crop.circle", title: "settings.personal_info".localized())
                }
                NavigationLink(destination: AccountSecurityView()) {
                    settingsRow(icon: "lock.shield.fill", title: "settings.account_security".localized())
                }
            }

            // MARK: - 可見性與隱私、通知
            Section {
                NavigationLink(destination: VisibilityPrivacyView()) {
                    settingsRow(icon: "eye.fill", title: "settings.visibility_privacy".localized())
                }
                NavigationLink(destination: NotificationsView()) {
                    settingsRow(icon: "bell.fill", title: "settings.notifications".localized())
                }
            }

            // MARK: - AI助手、外觀、內容偏好
            Section {
                NavigationLink(destination: AIAssistantPreferencesView()) {
                    settingsRow(icon: "wand.and.stars", title: "settings.ai_assistant".localized())
                }
                NavigationLink(destination: DarkModeSelectionView(darkModePreference: $darkModePreference, isDarkMode: $isDarkMode)) {
                    HStack {
                        settingsRowContent(icon: "moon.fill", title: "settings.dark_mode".localized())
                        Spacer()
                        Text(darkModeDisplayText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                NavigationLink(destination: LanguageSelectionView().environmentObject(localizationManager)) {
                    HStack {
                        settingsRowContent(icon: "globe", title: "settings.language".localized())
                        Spacer()
                        Text(localizationManager.localized(localizationManager.currentLanguage.localizedDisplayNameKey))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                NavigationLink(destination: ContentPreferencesView()) {
                    settingsRow(icon: "hand.thumbsup.fill", title: "settings.content_preferences".localized())
                }
            }

            // MARK: - 錢包與支付
            Section {
                NavigationLink(destination: WalletPaymentView()) {
                    settingsRow(icon: "creditcard.doc.plaintext.fill", title: "settings.wallet_payment".localized())
                }
            }

            // MARK: - 意見、快取、關於、隱私
            Section {
                NavigationLink(destination: FeedbackView()) {
                    settingsRow(icon: "bubble.left.and.bubble.right.fill", title: "settings.feedback".localized())
                }
                NavigationLink(destination: CachePerformanceView(cacheInfo: $cacheInfo)) {
                    settingsRow(icon: "gauge.with.dots.needle.67percent", title: "settings.cache_performance".localized())
                }
                NavigationLink(destination: AboutView(version: appVersion)) {
                    HStack {
                        settingsRowContent(icon: "info.circle.fill", title: "settings.about_version".localized())
                        Spacer()
                        Text("v\(appVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                NavigationLink(destination: PrivacyPolicyView()) {
                    settingsRow(icon: "doc.text.magnifyingglass", title: "settings.privacy_policy".localized())
                }
            }

            // MARK: - 切換帳號、登出
            Section {
                Button(action: { /* 預留：切換帳號 */ }) {
                    HStack {
                        Spacer()
                        Text("settings.switch_account".localized())
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Button(action: { showLogoutConfirmation = true }) {
                    HStack {
                        Spacer()
                        Text("settings.logout".localized())
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { updateCacheInfo() }
        .alert("settings.error".localized(), isPresented: $showErrorAlert) {
            Button("settings.ok".localized()) {}
        } message: { Text(errorMessage) }
        .confirmationDialog("settings.confirm_logout".localized(), isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
            Button("settings.yes".localized(), role: .destructive) {
                performLogout()
            }
            Button("common.cancel".localized(), role: .cancel) {}
        }
        .sheet(isPresented: $showSignInView) {
            AuthenticationView(showSignInView: $showSignInView)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("settings.copyright".localized())
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }

    private var darkModeDisplayText: String {
        switch darkModePreference {
        case "light": return "settings.dark_mode_light".localized()
        case "dark": return "settings.dark_mode_dark".localized()
        default: return "settings.dark_mode_system".localized()
        }
    }

    private func settingsRow(icon: String, title: String) -> some View {
        HStack {
            settingsRowContent(icon: icon, title: title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func settingsRowContent(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
        }
    }

    private func performLogout() {
        Task {
            do {
                if let userId = Auth.auth().currentUser?.uid {
                    FriendManager.shared.clearCache(for: userId)
                }
                try Auth.auth().signOut()
                showSignInView = true
            } catch {
                errorMessage = "settings.logout_failed".localized(with: error.localizedDescription)
                showErrorAlert = true
            }
        }
    }

    private func updateCacheInfo() {
        cacheInfo = (true, 1024 * 1024, Date())
    }
}

// MARK: - 帳號安全

struct AccountSecurityView: View {
    @StateObject private var userManager = FirebaseUserManager.shared
    @AppStorage("twoFactorEnabled") private var twoFactorEnabled = false
    @State private var isVerified = false

    private var authUser: User? { Auth.auth().currentUser }
    private var hasPhone: Bool {
        authUser?.phoneNumber != nil && !(authUser?.phoneNumber ?? "").isEmpty
    }
    private var hasPassword: Bool {
        authUser?.providerData.contains { $0.providerID == "password" } ?? false
    }
    private var loginMethodNames: [String] {
        guard let providers = authUser?.providerData else { return [] }
        return providers.map { providerName($0.providerID) }
    }

    var body: some View {
        List {
            Section {
                if !loginMethodNames.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("settings.login_methods".localized(), systemImage: "person.badge.key.fill")
                        Text(loginMethodNames.joined(separator: "、"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                NavigationLink(destination: PhoneBindingView().environmentObject(userManager)) {
                    HStack {
                        Label("settings.phone_binding".localized(), systemImage: "phone.fill")
                        Spacer()
                        Text(hasPhone ? (authUser?.phoneNumber ?? "settings.bound".localized()) : "settings.not_bound".localized())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                NavigationLink(destination: PasswordManageView().environmentObject(userManager)) {
                    HStack {
                        Label("settings.password_manage".localized(), systemImage: "key.fill")
                        Spacer()
                        Text(hasPassword ? "settings.set".localized() : "settings.not_set".localized())
                            .foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $twoFactorEnabled) {
                    Label("settings.two_factor".localized(), systemImage: "lock.shield.fill")
                }
                NavigationLink(destination: RealNameVerifyPlaceholderView()) {
                    HStack {
                        Label("settings.real_name_verify".localized(), systemImage: "checkmark.seal.fill")
                        Spacer()
                        Text(isVerified ? "settings.verified".localized() : "settings.not_verified".localized())
                            .foregroundColor(.secondary)
                    }
                }
            } footer: {
                Text("settings.account_security_footer".localized())
            }
        }
        .navigationTitle("settings.account_security".localized())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func providerName(_ providerId: String) -> String {
        switch providerId {
        case "google.com": return "login.google".localized()
        case "apple.com": return "login.apple".localized()
        case "password": return "login.email".localized()
        case "phone": return "login.phone".localized()
        case "anonymous": return "login.anonymous".localized()
        default: return providerId
        }
    }
}

// MARK: - 可見性與隱私

struct VisibilityPrivacyView: View {
    @AppStorage("profileVisibility") private var profileVisibility = "public"
    @AppStorage("defaultContentVisibility") private var defaultContentVisibility = "public"
    @AppStorage("allowSearchable") private var allowSearchable = true
    @AppStorage("allowRecommended") private var allowRecommended = true

    var body: some View {
        List {
            Section(header: Text("settings.profile_visibility".localized())) {
                Picker(selection: $profileVisibility) {
                    Text("settings.visibility_public".localized()).tag("public")
                    Text("settings.visibility_friends".localized()).tag("friends")
                    Text("settings.visibility_private".localized()).tag("private")
                } label: {
                    Label("settings.profile_visibility".localized(), systemImage: "person.2.fill")
                }
            }
            Section(header: Text("settings.default_content_visibility".localized())) {
                Picker(selection: $defaultContentVisibility) {
                    Text("settings.visibility_public".localized()).tag("public")
                    Text("settings.visibility_friends".localized()).tag("friends")
                    Text("settings.visibility_private".localized()).tag("private")
                } label: {
                    Label("settings.default_content_visibility".localized(), systemImage: "eye.fill")
                }
            }
            Section(header: Text("settings.discoverability".localized())) {
                Toggle(isOn: $allowSearchable) {
                    Label("settings.allow_searchable".localized(), systemImage: "magnifyingglass")
                }
                Toggle(isOn: $allowRecommended) {
                    Label("settings.allow_recommended".localized(), systemImage: "star.fill")
                }
            }
        }
        .navigationTitle("settings.visibility_privacy".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 通知與提醒

struct NotificationsView: View {
    @AppStorage("pushEnabled") private var pushEnabled = true
    @AppStorage("eventReminders") private var eventReminders = true
    @AppStorage("friendRequests") private var friendRequests = true
    @AppStorage("templateUpdates") private var templateUpdates = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $pushEnabled) {
                    Label("settings.push_enabled".localized(), systemImage: "bell.badge.fill")
                }
            } footer: {
                Text("settings.push_footer".localized())
            }
            Section(header: Text("settings.reminder_types".localized())) {
                Toggle(isOn: $eventReminders) {
                    Label("settings.event_reminders".localized(), systemImage: "calendar.badge.clock")
                }
                Toggle(isOn: $friendRequests) {
                    Label("settings.friend_requests".localized(), systemImage: "person.badge.plus")
                }
                Toggle(isOn: $templateUpdates) {
                    Label("settings.template_updates".localized(), systemImage: "doc.text.fill")
                }
            }
        }
        .navigationTitle("settings.notifications".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AI助手偏好

struct AIAssistantPreferencesView: View {
    @AppStorage("aiRecommendStyle") private var recommendStyle = "balanced"
    @AppStorage("aiOptimizationTendency") private var optimizationTendency = "balanced"
    @AppStorage("aiConversationMemory") private var conversationMemory = true

    var body: some View {
        List {
            Section(header: Text("settings.recommend_style".localized())) {
                Picker(selection: $recommendStyle) {
                    Text("settings.style_detailed".localized()).tag("detailed")
                    Text("settings.style_balanced".localized()).tag("balanced")
                    Text("settings.style_concise".localized()).tag("concise")
                } label: {
                    Label("settings.recommend_style".localized(), systemImage: "sparkles")
                }
            }
            Section(header: Text("settings.itinerary_optimization".localized())) {
                Picker(selection: $optimizationTendency) {
                    Text("settings.opt_relaxed".localized()).tag("relaxed")
                    Text("settings.opt_balanced".localized()).tag("balanced")
                    Text("settings.opt_intensive".localized()).tag("intensive")
                } label: {
                    Label("settings.itinerary_optimization".localized(), systemImage: "map.fill")
                }
            }
            Section {
                Toggle(isOn: $conversationMemory) {
                    Label("settings.conversation_memory".localized(), systemImage: "brain.head.profile")
                }
            } footer: {
                Text("settings.conversation_memory_footer".localized())
            }
        }
        .navigationTitle("settings.ai_assistant".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 內容偏好與推薦

struct ContentPreferencesView: View {
    @AppStorage("preferredThemes") private var preferredThemes = ""
    @AppStorage("homeRecommendDensity") private var homeRecommendDensity = "normal"

    var body: some View {
        List {
            Section(header: Text("settings.theme_preferences".localized())) {
                NavigationLink(destination: ThemePreferencePickerView()) {
                    HStack {
                        Label("settings.select_preferred_themes".localized(), systemImage: "tag.fill")
                        Spacer()
                        if !preferredThemes.isEmpty {
                            Text("settings.selected".localized())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            Section {
                Picker(selection: $homeRecommendDensity) {
                    Text("settings.density_less".localized()).tag("less")
                    Text("settings.density_normal".localized()).tag("normal")
                    Text("settings.density_more".localized()).tag("more")
                } label: {
                    Label("settings.home_recommend".localized(), systemImage: "square.grid.2x2.fill")
                }
            } header: {
                Text("settings.home_recommend".localized())
            } footer: {
                Text("settings.content_preferences_footer".localized())
            }
        }
        .navigationTitle("settings.content_preferences".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThemePreferencePickerView: View {
    @AppStorage("preferredThemes") private var preferredThemes = ""
    private let themeOptions = ["travel", "food", "culture", "nature", "shopping", "family"]

    private var selectedThemes: Set<String> {
        Set(preferredThemes.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    var body: some View {
        List {
            ForEach(themeOptions, id: \.self) { theme in
                Button(action: { toggleTheme(theme) }) {
                    HStack {
                        Text("settings.theme_\(theme)".localized())
                        Spacer()
                        if selectedThemes.contains(theme) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.select_preferred_themes".localized())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleTheme(_ theme: String) {
        var themes = selectedThemes
        if themes.contains(theme) {
            themes.remove(theme)
        } else {
            themes.insert(theme)
        }
        preferredThemes = themes.sorted().joined(separator: ",")
    }
}

// MARK: - 錢包與支付

struct WalletPaymentView: View {
    @AppStorage("paymentPasswordSet") private var paymentPasswordSet = false
    @AppStorage("faceIDEnabled") private var faceIDEnabled = false
    @State private var balance = "NT$ 0"

    var body: some View {
        List {
            Section(header: Text("settings.security".localized())) {
                NavigationLink(destination: PaymentPasswordPlaceholderView()) {
                    HStack {
                        Label("settings.payment_password".localized(), systemImage: "key.fill")
                        Spacer()
                        Text(paymentPasswordSet ? "settings.set".localized() : "settings.not_set".localized())
                            .foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $faceIDEnabled) {
                    Label("settings.face_id".localized(), systemImage: "faceid")
                }
            }
            Section(header: Text("settings.balance".localized())) {
                NavigationLink(destination: BusinessCenterDetailView()) {
                    HStack {
                        Label("settings.balance".localized(), systemImage: "dollarsign.circle.fill")
                        Spacer()
                        Text(balance)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Section(header: Text("settings.bills".localized())) {
                NavigationLink(destination: BillsPlaceholderView()) {
                    Label("settings.view_bills".localized(), systemImage: "doc.text.fill")
                }
            }
        }
        .navigationTitle("settings.wallet_payment".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 意見與反饋

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var showSent = false

    var body: some View {
        List {
            Section {
                ZStack(alignment: .topLeading) {
                    if feedbackText.isEmpty {
                        Text("settings.feedback_placeholder".localized())
                            .foregroundColor(.secondary)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 120)
                        .padding(4)
                }
            } header: {
                Text("settings.feedback_content".localized())
            } footer: {
                Text("settings.feedback_footer".localized())
            }
            Section {
                Button(action: submitFeedback) {
                    HStack {
                        Spacer()
                        Text("settings.submit_feedback".localized())
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .navigationTitle("settings.feedback".localized())
        .navigationBarTitleDisplayMode(.inline)
        .alert("settings.feedback_sent".localized(), isPresented: $showSent) {
            Button("settings.ok".localized()) { feedbackText = "" }
        } message: {
            Text("settings.feedback_sent_message".localized())
        }
    }

    private func submitFeedback() {
        guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        hideKeyboard()
        showSent = true
    }
}

struct CachePerformanceView: View {
    @Binding var cacheInfo: (exists: Bool, size: Int64, lastModified: Date?)
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var showClearCacheConfirmation = false

    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var body: some View {
        List {
            if cacheInfo.exists {
                HStack {
                    Text("settings.cache_size".localized())
                    Spacer()
                    Text(formatFileSize(cacheInfo.size))
                        .foregroundColor(.secondary)
                }
                if let lastModified = cacheInfo.lastModified {
                    HStack {
                        Text("settings.last_updated".localized())
                        Spacer()
                        Text(localizationManager.formatDate(lastModified))
                            .foregroundColor(.secondary)
                    }
                }
                Button("settings.clear_cache".localized()) {
                    showClearCacheConfirmation = true
                }
                .foregroundColor(.red)
            } else {
                Text("settings.no_cache".localized())
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("settings.cache_performance".localized())
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("settings.confirm_clear_cache".localized(), isPresented: $showClearCacheConfirmation, titleVisibility: .visible) {
            Button("settings.yes".localized(), role: .destructive) {
                cacheInfo = (false, 0, nil)
            }
            Button("common.cancel".localized(), role: .cancel) {}
        }
    }
}

struct AboutView: View {
    let version: String

    var body: some View {
        List {
            Section {
                HStack {
                    Text("settings.app_version".localized())
                    Spacer()
                    Text("v\(version)")
                        .foregroundColor(.secondary)
                }
            }
            Section {
                Text("settings.developed_by".localized())
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("settings.about_version".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("settings.privacy_policy_content".localized())
                .font(.body)
                .foregroundColor(.primary)
                .padding()
        }
        .navigationTitle("settings.privacy_policy".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 手機綁定

struct PhoneBindingView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var phoneNumber = ""
    @State private var countryCode = "+886"
    @State private var verificationCode = ""
    @State private var verificationCodeSent = false
    @State private var isSendingCode = false
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showSuccessAlert = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("+")
                    TextField("886", text: $countryCode)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                    Divider()
                    TextField("settings.phone_placeholder".localized(), text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                .disabled(verificationCodeSent)

                if verificationCodeSent {
                    TextField("settings.verification_code".localized(), text: $verificationCode)
                        .keyboardType(.numberPad)
                }
            } header: {
                Text("settings.phone_number".localized())
            } footer: {
                if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                }
            }

            Section {
                if verificationCodeSent {
                    Button(action: {
                    hideKeyboard()
                    Task { await verifyCode() }
                }) {
                        HStack {
                            Spacer()
                            if isVerifying {
                                ProgressView()
                            } else {
                                Text("settings.verify_and_bind".localized())
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .disabled(verificationCode.isEmpty || isVerifying)

                    Button("settings.resend_code".localized()) {
                        hideKeyboard()
                        PhoneVerificationManager.shared.clearVerificationID()
                        Task { await sendCode() }
                    }
                    .disabled(isSendingCode)
                } else {
                    Button(action: {
                        hideKeyboard()
                        Task { await sendCode() }
                    }) {
                        HStack {
                            Spacer()
                            if isSendingCode {
                                ProgressView()
                            } else {
                                Text("settings.send_verification_code".localized())
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .disabled(phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty || isSendingCode)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .navigationTitle("settings.phone_binding".localized())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let phone = Auth.auth().currentUser?.phoneNumber ?? userManager.phone, !phone.isEmpty {
                let cleaned = phone.replacingOccurrences(of: "+", with: "")
                if cleaned.hasPrefix("886") {
                    countryCode = "+886"
                    phoneNumber = String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                } else {
                    phoneNumber = phone
                }
            }
        }
        .alert("settings.error".localized(), isPresented: $showErrorAlert) {
            Button("settings.ok".localized()) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert("settings.phone_bind_success".localized(), isPresented: $showSuccessAlert) {
            Button("settings.ok".localized()) {}
        } message: { Text("settings.phone_bind_success_message".localized()) }
    }

    private func sendCode() async {
        let phone = phoneNumber.trimmingCharacters(in: .whitespaces)
        guard !phone.isEmpty else {
            errorMessage = "settings.phone_required".localized()
            showErrorAlert = true
            return
        }
        isSendingCode = true
        errorMessage = nil
        do {
            _ = try await PhoneVerificationManager.shared.sendVerificationCode(to: phone, countryCode: countryCode)
            verificationCodeSent = true
        } catch {
            errorMessage = "settings.send_code_failed".localized(with: error.localizedDescription)
            showErrorAlert = true
        }
        isSendingCode = false
    }

    private func verifyCode() async {
        guard !verificationCode.isEmpty else {
            errorMessage = "settings.code_required".localized()
            showErrorAlert = true
            return
        }
        isVerifying = true
        errorMessage = nil
        do {
            try await PhoneVerificationManager.shared.verifyCode(verificationCode)
            if let userId = Auth.auth().currentUser?.uid {
                try? await UserManager.shared.updatePhone(for: userId, to: "\(countryCode)\(phoneNumber.trimmingCharacters(in: .whitespaces))")
                try? await UserManager.shared.updatePhoneVerified(for: userId, verified: true)
            }
            userManager.refresh()
            showSuccessAlert = true
        } catch {
            errorMessage = "settings.verify_failed".localized(with: error.localizedDescription)
            showErrorAlert = true
        }
        isVerifying = false
    }
}

// MARK: - 密碼管理

struct PasswordManageView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var linkEmail = ""
    @State private var isChanging = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var showResetEmailSent = false

    private var hasPassword: Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == "password" } ?? false
    }
    private var userEmail: String? { Auth.auth().currentUser?.email }

    var body: some View {
        passwordListContent
            .navigationTitle("settings.password_manage".localized())
            .navigationBarTitleDisplayMode(.inline)
            .alert("settings.error".localized(), isPresented: $showErrorAlert) {
                Button("settings.ok".localized()) {}
            } message: { Text(errorMessage) }
            .alert("settings.success".localized(), isPresented: $showSuccessAlert) {
                Button("settings.ok".localized()) {}
            } message: { Text("settings.password_updated".localized()) }
            .alert("settings.reset_email_sent".localized(), isPresented: $showResetEmailSent) {
                Button("settings.ok".localized()) {}
            } message: { Text("settings.reset_email_sent_message".localized(with: userEmail ?? "")) }
    }
    
    @ViewBuilder
    private var passwordListContent: some View {
        List {
            if hasPassword {
                changePasswordSections
            } else {
                setPasswordSections
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
    
    @ViewBuilder
    private var changePasswordSections: some View {
        Section(header: Text("settings.change_password".localized())) {
            SecureField("settings.current_password".localized(), text: $currentPassword)
            SecureField("settings.new_password".localized(), text: $newPassword)
            SecureField("settings.confirm_password".localized(), text: $confirmPassword)
        }
        Section {
            changePasswordButton
        }
        if let email = userEmail, !email.isEmpty {
            Section(header: Text("settings.reset_password".localized())) {
                Button("settings.send_reset_email".localized()) {
                    Task { await sendResetEmail() }
                }
            }
        }
    }
    
    private var changePasswordButton: some View {
        Button(action: {
            hideKeyboard()
            Task { await changePassword() }
        }) {
            HStack {
                Spacer()
                if isChanging {
                    ProgressView()
                } else {
                    Text("settings.update_password".localized())
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .disabled(!canChangePassword || isChanging)
    }
    
    @ViewBuilder
    private var setPasswordSections: some View {
        Section(
            header: Text("settings.set_password".localized()),
            footer: Text("settings.set_password_footer".localized())
        ) {
            setPasswordFields
            SecureField("settings.new_password".localized(), text: $newPassword)
            SecureField("settings.confirm_password".localized(), text: $confirmPassword)



        }
    }
    
    @ViewBuilder
    private var setPasswordFields: some View {
        if let email = userEmail, !email.isEmpty {
            HStack {
                Text("settings.email".localized())
                Spacer()
                Text(email)
                    .foregroundColor(.secondary)
            }
        } else {
            TextField("settings.email".localized(), text: $linkEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
        }
    }
    
    private var setPasswordButton: some View {
        Button(action: {
            hideKeyboard()
            Task { await setPassword() }
        }) {
            HStack {
                Spacer()
                if isChanging {
                    ProgressView()
                } else {
                    Text("settings.set_password".localized())
                }
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .disabled(!canSetPassword || isChanging)
    }

    private var canChangePassword: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && newPassword == confirmPassword && newPassword.count >= 6
    }

    private var canSetPassword: Bool {
        let emailOk = (userEmail != nil && !(userEmail ?? "").isEmpty) || !linkEmail.isEmpty
        return emailOk && !newPassword.isEmpty && newPassword == confirmPassword && newPassword.count >= 6
    }

    private func changePassword() async {
        guard canChangePassword else { return }
        isChanging = true
        errorMessage = ""
        do {
            guard let email = userEmail else {
                errorMessage = "settings.email_required".localized()
                showErrorAlert = true
                isChanging = false
                return
            }
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            _ = try await Auth.auth().currentUser?.reauthenticate(with: credential)
            try await AuthenticationManager.shared.updatePassword(password: newPassword)
            showSuccessAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
        isChanging = false
    }

    private func setPassword() async {
        guard canSetPassword else { return }
        let email = userEmail ?? linkEmail
        guard !email.isEmpty else {
            errorMessage = "settings.link_email_first".localized()
            showErrorAlert = true
            return
        }
        isChanging = true
        errorMessage = ""
        do {
            _ = try await AuthenticationManager.shared.linkEmail(email: email, password: newPassword)
            showSuccessAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
        isChanging = false
    }

    private func sendResetEmail() async {
        guard let email = userEmail, !email.isEmpty else { return }
        do {
            try await AuthenticationManager.shared.resetPassword(email: email)
            showResetEmailSent = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

struct RealNameVerifyPlaceholderView: View {
    var body: some View {
        Text("settings.real_name_verify".localized())
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("settings.real_name_verify".localized())
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct PaymentPasswordPlaceholderView: View {
    var body: some View {
        Text("settings.payment_password".localized())
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("settings.payment_password".localized())
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct BillsPlaceholderView: View {
    var body: some View {
        Text("settings.view_bills".localized())
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("settings.bills".localized())
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 深色模式選擇

struct DarkModeSelectionView: View {
    @Binding var darkModePreference: String
    @Binding var isDarkMode: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            ForEach(["system", "light", "dark"], id: \.self) { option in
                Button(action: {
                    darkModePreference = option
                    isDarkMode = (option == "dark")
                    dismiss()
                }) {
                    HStack {
                        Text(displayText(for: option))
                        Spacer()
                        if darkModePreference == option {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("settings.dark_mode".localized())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func displayText(for option: String) -> String {
        switch option {
        case "system": return "settings.dark_mode_system".localized()
        case "light": return "settings.dark_mode_light".localized()
        case "dark": return "settings.dark_mode_dark".localized()
        default: return option
        }
    }
}

// MARK: - 語言選擇視圖（保留原有）

struct LanguageSelectionView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button(action: {
                        localizationManager.setLanguage(language)
                        dismiss()
                    }) {
                        HStack {
                            Text(localizationManager.localized(language.localizedDisplayNameKey))
                            Spacer()
                            if localizationManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } footer: {
                Text(localizationManager.localized("settings.language_footer"))
                    .font(.caption)
            }
        }
        .navigationTitle(localizationManager.localized("settings.language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView(showSignInView: .constant(false))
            .environmentObject(LocalizationManager.shared)
    }
}
