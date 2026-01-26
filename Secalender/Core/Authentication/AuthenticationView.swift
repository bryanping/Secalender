//
//  AuthenticationView.swift
//  Secalender
//
//  Created by linping on 2024/6/13.
//

import SwiftUI
import GoogleSignIn
import FirebaseAuth

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @Binding var showSignInView: Bool

    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.89, green: 0.95, blue: 0.99), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 80)
                    
                    // LOGO区域
                    VStack(spacing: 24) {
                        Image("LOGO")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        // 标题区域
                        VStack(spacing: 8) {
                            Text("SECALENDER")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Plan your next adventure with AI")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 100)
                    
                    // 按钮区域
                    VStack(spacing: 12) {
                        // Google登录按钮
                        Button {
                            Task {
                                do {
                                    try await viewModel.signInGoogle()
                                    await handlePostLogin()
                                } catch {
                                    print("登入失败：\(error)")
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                // Google 官方 LOGO
                                Image("GoogleLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                        }
                        
                        // Apple登录按钮
                        Button {
                            Task {
                                do {
                                    try await viewModel.signInApple()
                                    await handlePostLogin()
                                } catch {
                                    print(error)
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20, weight: .medium))
                                Text("Continue with Apple")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )
                        }
                        
                        // OR分隔符
                        HStack(spacing: 16) {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 1)
                            
                            Text("OR")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                            
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)
                        
                        // Email登录链接
                        NavigationLink {
                            SignInEmailView(showSignInView: $showSignInView)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Continue with Email")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                        
                        // 注册链接
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                            
                            Button {
                                // 可以添加注册逻辑
                            } label: {
                                Text("Sign Up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 24)
                        
                        // 匿名登录按钮
                        Button {
                            Task {
                                do {
                                    try await viewModel.signInAnonymous()
                                    await handlePostLogin()
                                } catch {
                                    print("匿名登入失败：\(error.localizedDescription)")
                                }
                            }
                        } label: {
                            Text("跳过登入，开始使用")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 25)
                        
                        // 使用条款
                        Text("登入即表示同意我们的使用条款与隐私政策")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                            .padding(.horizontal, 10)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 400)
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }
    private func handlePostLogin() async {
            guard let authUser = try? AuthenticationManager.shared.getAuthenticatedUser() else {
                return
            }

            // 建立使用者 Firestore 资料（若不存在）
            do {
                try await UserManager.shared.createNewUser(auth: authUser)
            } catch {
                print("用户创建跳过（可能已存在）")
            }

            // 强制刷新 User 状态（包含 alias、role、好友清单等）
            await FirebaseUserManager.shared.refresh()

            // 收起登入视图
            DispatchQueue.main.async {
                showSignInView = false
            }
        }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AuthenticationView(showSignInView: .constant(false))
        }
    }
}
//
//#Preview {
//    AuthenticationView(showSignInView: .constant(false))
//        .environmentObject(FirebaseUserManager.shared)
//}
