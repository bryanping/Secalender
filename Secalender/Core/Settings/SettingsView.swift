import SwiftUI
import FirebaseAuth
import Foundation

// 导入必要的模型和管理器

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Binding var showSignInView: Bool
    @StateObject private var userManager = FirebaseUserManager.shared
    @State private var showLogoutConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showClearCacheConfirmation = false
    @State private var cacheInfo: (exists: Bool, size: Int64, lastModified: Date?) = (false, 0, nil)

    var body: some View {
        Form {
            // 账户设定
            Section(header: Text("账户设定")) {
                if let user = Auth.auth().currentUser {
                    Label("登入方式：\(signInProviderName(user))", systemImage: "person.crop.circle")
                    if let email = user.email {
                        Label("登入帐号：\(email)", systemImage: "envelope")
                    }

                    if user.isAnonymous {
                        Button("会员登入") {
                            showSignInView = true
                        }
                    } else {
                        Button("登出") {
                            showLogoutConfirmation = true
                        }
                    }
                } else {
                    Button("会员登入") {
                        showSignInView = true
                    }
                }
            }

            // 偏好设定
            Section(header: Text("偏好设定")) {
                Toggle(isOn: $isDarkMode) {
                    Label("深色模式", systemImage: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                }
            }
            
            // 缓存管理
            Section(header: Text("缓存管理")) {
                if cacheInfo.exists {
                    HStack {
                        Label("缓存大小", systemImage: "externaldrive")
                        Spacer()
                        Text(formatFileSize(cacheInfo.size))
                            .foregroundColor(.gray)
                    }
                    
                    if let lastModified = cacheInfo.lastModified {
                        HStack {
                            Label("最后更新", systemImage: "clock")
                            Spacer()
                            Text(formatDate(lastModified))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button("清除行程缓存") {
                        showClearCacheConfirmation = true
                    }
                    .foregroundColor(.red)
                } else {
                    Label("暂无缓存数据", systemImage: "externaldrive")
                        .foregroundColor(.gray)
                }
            }

            // 应用信息
            Section(header: Text("关于应用")) {
                Label("Secalender v1.0", systemImage: "info.circle")
                Text("由 ChatGPT & 林平开发")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("设定")
        .onAppear {
            updateCacheInfo()
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("好") {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("确定要登出吗？", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
            Button("是", role: .destructive) {
                Task {
                    do {
                        try Auth.auth().signOut()
                        showSignInView = true
                    } catch {
                        errorMessage = "登出失败：\(error.localizedDescription)"
                        showErrorAlert = true
                    }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("确定要清除缓存吗？", isPresented: $showClearCacheConfirmation, titleVisibility: .visible) {
            Button("是", role: .destructive) {
                Task {
                    // 清除缓存
                    // 暂时注释掉缓存清理功能
                    // await EventCacheManager.shared.clearCache()
                    updateCacheInfo()
                }
            }
            Button("取消", role: .cancel) {}
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// 🔹 解析登入渠道
    private func signInProviderName(_ user: User) -> String {
        let providerId = user.providerData.first?.providerID ?? ""
        switch providerId {
        case "google.com": return "Google登入"
        case "apple.com": return "Apple登入"
        case "password": return "邮箱登入"
        case "facebook.com": return "Facebook登入"
        case "phone": return "手机登入"
        case "anonymous": return "匿名"
        default: return providerId
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(showSignInView: .constant(false))
    }
}
