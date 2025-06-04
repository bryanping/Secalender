//
//  SettingsView.swift
//  Secalender
//
//  Created by linping on 2024/6/14.
//

//
//  SettingsView.swift
//  Secalender
//
//  Created by linping on 2025/6/5.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Binding var showSignInView: Bool
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            // 账户
            Section(header: Text("账户设定")) {
                Button("登出") {
                    Task {
                        do {
                            try viewModel.signOut()
                            showSignInView = true
                        } catch {
                            print("登出失败: \(error.localizedDescription)")
                        }
                    }
                }

                Button(role: .destructive) {
                    Task {
                        do {
                            try await viewModel.deleteAccount()
                            showSignInView = true
                        } catch {
                            print("删除失败: \(error.localizedDescription)")
                        }
                    }
                } label: {
                    Text("删除账号")
                }
            }

            // 邮箱功能
            if viewModel.authProviders.contains(.email) {
                emailSection
            }

            // 匿名用户绑定
            if viewModel.authUser?.isAnonymous == true {
                anonymousSection
            }

            // 偏好设定
            Section(header: Text("偏好设定")) {
                Toggle(isOn: $isDarkMode) {
                    Label("深色模式", systemImage: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                }
            }

            // 应用信息
            Section(header: Text("关于应用")) {
                Label("Secalender v1.0", systemImage: "info.circle")
                Text("由 ChatGPT & 林平开发").font(.footnote).foregroundColor(.gray)
            }
        }
        .navigationTitle("设定")
        .onAppear {
            viewModel.loadAuthProviders()
            viewModel.loadAuthUser()
        }
    }

    private var emailSection: some View {
        Section(header: Text("邮箱功能")) {
            Button("重设密码") {
                Task {
                    do {
                        try await viewModel.resetPassword()
                        print("密码已重设")
                    } catch {
                        print("重设密码失败: \(error.localizedDescription)")
                    }
                }
            }

            Button("更新密码") {
                Task {
                    do {
                        try await viewModel.updatePassword()
                        print("密码已更新")
                    } catch {
                        print("更新密码失败: \(error.localizedDescription)")
                    }
                }
            }

            Button("更新邮箱") {
                Task {
                    do {
                        try await viewModel.updateEmail()
                        print("邮箱已更新")
                    } catch {
                        print("更新邮箱失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private var anonymousSection: some View {
        Section(header: Text("匿名绑定功能")) {
            Button("绑定 Google") {
                Task {
                    do {
                        try await viewModel.linkGoogleAccount()
                        print("已绑定 Google")
                    } catch {
                        print("绑定失败: \(error.localizedDescription)")
                    }
                }
            }

            Button("绑定 Apple") {
                Task {
                    do {
                        try await viewModel.linkAppleAccount()
                        print("已绑定 Apple")
                    } catch {
                        print("绑定失败: \(error.localizedDescription)")
                    }
                }
            }

            Button("绑定 Email") {
                Task {
                    do {
                        try await viewModel.linkEmailAccount()
                        print("已绑定 Email")
                    } catch {
                        print("绑定失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(showSignInView: .constant(false))
    }
}
