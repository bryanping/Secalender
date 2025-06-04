//
//  AuthenticationView.swift
//  Secalender
//
//  Created by linping on 2024/6/13.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import FirebaseAuth

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @Binding var showSignInView: Bool

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            
            Image("LOGO") // 替换为你 app 的 logo
                           // .resizable()
                            .frame(width: 120, height: 120)
            
            Text("Secalender")
                            .font(.largeTitle)
                            .bold()
                            .padding(.top, 100)

            Text("註冊後開啟你的時間管理生活")
                            .font(.subheadline)
                            .foregroundColor(.gray)

            
            
            GoogleSignInButton(
                scheme: .light,
                style: .wide,
                state: .normal
            ) {
                Task {
                    do {
                        try await viewModel.signInGoogle()
                        await handlePostLogin()
                    } catch {
                        print("登入失败：\(error)")
                    }
                }
            }
            .frame(height: 48)
            .padding(.horizontal)
            
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
                HStack {
                    Image(systemName: "apple.logo")
                    Text("使用 Apple 登入")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            Text("或")
                .padding(-5)
            .foregroundColor(.gray)

            NavigationLink {
                SignInEmailView(showSignInView: $showSignInView)
            } label: {
                Text("以电子信箱登入或注册新帐号")
                .font(.headline)
                .frame(height: 48)
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            Button {
                Task {
                    do {
                        try await viewModel.signInAnonymous()
                        await handlePostLogin()
                    } catch {
                        print("匿名登入失败：\(error.localizedDescription)")
                    }
                }
            }
            label: {
                Text("跳过登入，开始使用")
                .font(.footnote)
                .foregroundColor(.gray)
            }
            
            
                Text("登入即表示同意我们的使用条款与隐私政策")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            
            
            
        }
        .padding()
        //.navigationTitle("Sign In")
        .background(Color(.systemBackground))
        
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
