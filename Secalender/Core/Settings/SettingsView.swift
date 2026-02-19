import SwiftUI
import FirebaseAuth
import Foundation

// 导入必要的模型和管理器

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Binding var showSignInView: Bool
    @StateObject private var userManager = FirebaseUserManager.shared
    @EnvironmentObject var localizationManager: LocalizationManager
    @State private var showLogoutConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showClearCacheConfirmation = false
    @State private var cacheInfo: (exists: Bool, size: Int64, lastModified: Date?) = (false, 0, nil)

    var body: some View {
        Form {
            // 账户设定
            Section(header: Text("settings.account".localized())) {
                if let user = Auth.auth().currentUser {
                    Label("settings.login_method".localized(with: signInProviderName(user)), systemImage: "person.crop.circle")
                    if let email = user.email {
                        Label("settings.login_account".localized(with: email), systemImage: "envelope")
                    }

                    if user.isAnonymous {
                        Button("settings.member_login".localized()) {
                            showSignInView = true
                        }
                    } else {
                        Button("settings.logout".localized()) {
                            showLogoutConfirmation = true
                        }
                    }
                } else {
                    Button("settings.member_login".localized()) {
                        showSignInView = true
                    }
                }
            }

            // 偏好设定
            Section(header: Text("settings.preferences".localized())) {
                Toggle(isOn: $isDarkMode) {
                    Label("settings.dark_mode".localized(), systemImage: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                }
                
                // 语言设置
                NavigationLink {
                    LanguageSelectionView()
                        .environmentObject(localizationManager)
                } label: {
                    HStack {
                        Label("settings.language".localized(), systemImage: "globe")
                        Spacer()
                        Text(localizationManager.localized(localizationManager.currentLanguage.localizedDisplayNameKey))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 缓存管理
            Section(header: Text("settings.cache_management".localized())) {
                if cacheInfo.exists {
                    HStack {
                        Label("settings.cache_size".localized(), systemImage: "externaldrive")
                        Spacer()
                        Text(formatFileSize(cacheInfo.size))
                            .foregroundColor(.gray)
                    }
                    
                    if let lastModified = cacheInfo.lastModified {
                        HStack {
                            Label("settings.last_updated".localized(), systemImage: "clock")
                            Spacer()
                            Text(localizationManager.formatDate(lastModified))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button("settings.clear_cache".localized()) {
                        showClearCacheConfirmation = true
                    }
                    .foregroundColor(.red)
                } else {
                    Label("settings.no_cache".localized(), systemImage: "externaldrive")
                        .foregroundColor(.gray)
                }
            }

            // 应用信息
            Section(header: Text("settings.about".localized())) {
                Label("settings.app_version".localized(), systemImage: "info.circle")
                Text("settings.developed_by".localized())
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("settings.title".localized())
        .onAppear {
            updateCacheInfo()
        }
        .alert("settings.error".localized(), isPresented: $showErrorAlert) {
            Button("settings.ok".localized()) {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("settings.confirm_logout".localized(), isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
            Button("settings.yes".localized(), role: .destructive) {
                Task {
                    do {
                        // 清除朋友名单缓存
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
            Button("common.cancel".localized(), role: .cancel) {}
        }
        .confirmationDialog("settings.confirm_clear_cache".localized(), isPresented: $showClearCacheConfirmation, titleVisibility: .visible) {
            Button("settings.yes".localized(), role: .destructive) {
                Task {
                    // 清除缓存
                    // 暂时注释掉缓存清理功能
                    // await EventCacheManager.shared.clearCache()
                    updateCacheInfo()
                }
            }
            Button("common.cancel".localized(), role: .cancel) {}
        }
        .sheet(isPresented: $showSignInView) {
            AuthenticationView(showSignInView: $showSignInView)
        }
    }
    
    // MARK: - 缓存相关方法
    
    private func updateCacheInfo() {
        // 获取缓存信息
        // 暂时使用模拟数据
        cacheInfo = (true, 1024 * 1024, Date())
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// 🔹 解析登入渠道
    private func signInProviderName(_ user: User) -> String {
        let providerId = user.providerData.first?.providerID ?? ""
        switch providerId {
        case "google.com": return "login.google".localized()
        case "apple.com": return "login.apple".localized()
        case "password": return "login.email".localized()
        case "facebook.com": return "login.facebook".localized()
        case "phone": return "login.phone".localized()
        case "anonymous": return "login.anonymous".localized()
        default: return providerId
        }
    }
    
}

// MARK: - 语言选择视图
struct LanguageSelectionView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Form {
            Section {
                // 所有支持的语言（包括系统语言）
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
    }
}
