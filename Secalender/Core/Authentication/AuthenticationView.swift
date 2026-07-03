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
    @State private var showBasicInfo: Bool = false
    @State private var showEmailSignIn: Bool = false

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
                                .foregroundColor(.black)
                            
                            Text("auth.subtitle".localized())
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.gray)
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
                                Text("auth.continue_with_google".localized())
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
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
                                    .foregroundColor(.black)
                                Text("auth.continue_with_apple".localized())
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
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
                            
                            Text("auth.or".localized())
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)
                        
                        // Email登录按钮
                        Button {
                            print("🔵 Email登入按鈕被點擊")
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showEmailSignIn = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18, weight: .medium))
                                Text("auth.continue_with_email".localized())
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 10)
                        
                        // 注册链接
                        HStack(spacing: 4) {
                            Text("auth.no_account".localized())
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                            
                            Button {
                                print("🔵 註冊按鈕被點擊")
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showEmailSignIn = true
                                }
                            } label: {
                                Text("auth.sign_up".localized())
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 24)
                        
                        // 匿名登录按钮
                        Button {
                            Task {
                                await handleSkipLogin()
                            }
                        } label: {
                            Text("auth.skip_login".localized())
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 25)
                        
                        // 使用条款
                        Text("auth.terms_agreement".localized())
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
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
        .sheet(isPresented: $showBasicInfo) {
            BasicInfoView(isPresented: $showBasicInfo) {
                // 基本资料填写完成后，检查是否需要关闭登录视图
                Task {
                    await checkAndCloseLoginIfNeeded()
                }
            }
        }
        .fullScreenCover(isPresented: $showEmailSignIn) {
            NavigationStack {
                SignInEmailView(showSignInView: $showSignInView)
                    .onAppear {
                        print("✅ Email登入頁面已顯示")
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showEmailSignIn = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
            }
        }
    }
    
    private func handleSkipLogin() async {
        do {
            print("開始匿名登入...")
            try await viewModel.signInAnonymous()
            print("匿名登入成功")
            await handlePostLogin()
        } catch {
            print("匿名登入失败：\(error.localizedDescription)")
            // 即使失敗，也嘗試顯示基本資料頁面
            await handlePostLogin()
        }
    }
    
    private func handlePostLogin() async {
        guard let authUser = try? AuthenticationManager.shared.getAuthenticatedUser() else {
            print("無法獲取認證用戶")
            return
        }

        print("登入成功，用戶ID：\(authUser.uid)")

        // 注意：createNewUser 已經在 AuthenticationViewModel 中處理了
        // 這裡只需要檢查是否需要填寫基本資料

        // 强制刷新 User 状态（包含 alias、role、好友清单等）
        FirebaseUserManager.shared.refresh()

        // 等待一下，確保用戶資料已創建
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

        // 檢查是否需要填寫基本資料
        await checkAndShowBasicInfoIfNeeded(userId: authUser.uid)
    }
    
    private func checkAndShowBasicInfoIfNeeded(userId: String) async {
        do {
            let needsBasicInfo = try await UserManager.shared.needsBasicInfo(userId: userId)
            
            print("檢查基本資料，需要填寫：\(needsBasicInfo)")
            
            await MainActor.run {
                if needsBasicInfo {
                    // 需要填寫基本資料，顯示基本資料頁面
                    print("顯示基本資料頁面")
                    showBasicInfo = true
                } else {
                    // 不需要，直接收起登入視圖
                    print("基本資料已完成，關閉登入視圖")
                    withAnimation {
                        showSignInView = false
                    }
                }
            }
        } catch {
            print("檢查基本資料狀態失敗：\(error)")
            // 發生錯誤時，仍然顯示基本資料頁面，確保用戶可以填寫
            await MainActor.run {
                print("發生錯誤，顯示基本資料頁面")
                showBasicInfo = true
            }
        }
    }
    
    private func checkAndCloseLoginIfNeeded() async {
        guard let authUser = try? AuthenticationManager.shared.getAuthenticatedUser() else {
            return
        }
        
        // 等待一下，确保数据已保存
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 再次刷新用户状态
        FirebaseUserManager.shared.refresh()
        
        // 检查基本资料是否已完成
        do {
            let needsBasicInfo = try await UserManager.shared.needsBasicInfo(userId: authUser.uid)
            
            await MainActor.run {
                if !needsBasicInfo {
                    // 基本资料已完成，关闭基本资料页面和登录视图
                    showBasicInfo = false
                    withAnimation {
                        showSignInView = false
                    }
                }
            }
        } catch {
            print("檢查基本資料狀態失敗：\(error)")
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
