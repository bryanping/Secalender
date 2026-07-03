//
//  SignInEmailView.swift
//  Secalender
//
//  Created by linping on 2024/6/13.
//

import SwiftUI

@MainActor
struct SignInEmailView: View {
    
    @StateObject private var viewModel = SignInEmailViewModel()
    @Binding var showSignInView: Bool
    @State private var showBasicInfo: Bool = false
    @State private var showEmailVerification: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var isSignUpMode: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Email...", text: $viewModel.email)
                .padding()
                .background(Color.gray.opacity(0.4))
                .cornerRadius(10)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .disabled(isLoading)
            
            SecureField("Password...", text: $viewModel.password)
                .padding()
                .background(Color.gray.opacity(0.4))
                .cornerRadius(10)
                .disabled(isLoading)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // 主按钮（登录或注册）
            Button {
                Task {
                    if isSignUpMode {
                        await handleSignUp()
                    } else {
                        await handleSignIn()
                    }
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.trailing, 8)
                    }
                    Text(isSignUpMode ? "註冊" : "登入")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(height: 55)
                .frame(maxWidth: .infinity)
                .background(isLoading ? Color.gray : Color.blue)
                .cornerRadius(10)
            }
            .disabled(isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
            
            // 忘记密码按钮
            if !isSignUpMode {
                Button {
                    showForgotPassword = true
                } label: {
                    Text("忘記密碼？")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
            }
            
            // 切换登录/注册模式
            HStack(spacing: 4) {
                Text(isSignUpMode ? "已有帳號？" : "還沒有帳號？")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Button {
                    withAnimation {
                        isSignUpMode.toggle()
                        errorMessage = nil
                    }
                } label: {
                    Text(isSignUpMode ? "登入" : "註冊")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
        .navigationTitle(isSignUpMode ? "註冊" : "登入")
        .sheet(isPresented: $showBasicInfo) {
            BasicInfoView(isPresented: $showBasicInfo) {
                // 基本资料填写完成后，检查是否需要关闭登录视图
                Task {
                    await checkAndCloseLoginIfNeeded()
                }
            }
        }
        .sheet(isPresented: $showEmailVerification) {
            EmailVerificationView(
                isPresented: $showEmailVerification,
                showSignInView: $showSignInView,
                email: viewModel.email
            )
        }
        .alert("忘記密碼", isPresented: $showForgotPassword) {
            TextField("請輸入您的電子郵件", text: $viewModel.email)
            Button("取消", role: .cancel) { }
            Button("發送") {
                Task {
                    await handleForgotPassword()
                }
            }
        } message: {
            Text("我們將向您的電子郵件發送密碼重置連結")
        }
    }
    
    /// 处理注册流程
    private func handleSignUp() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 1. 创建用户
            try await viewModel.signUp()
            
            // 2. 发送验证邮件
            try await viewModel.sendEmailVerification()
            
            // 3. 显示"去收信"页面
            await MainActor.run {
                isLoading = false
                showEmailVerification = true
            }
            
            print("✅ 註冊成功，已發送驗證郵件")
        } catch {
            await MainActor.run {
                errorMessage = getErrorMessage(from: error)
                isLoading = false
            }
            print("❌ 註冊失敗：\(error)")
        }
    }
    
    /// 处理登录流程
    private func handleSignIn() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 1. 登录
            try await viewModel.signIn()
            
            // 2. 重新加载用户信息以获取最新的验证状态
            try await viewModel.reloadUser()
            
            // 3. 检查邮箱是否已验证
            let isVerified = try viewModel.isEmailVerified()
            
            if !isVerified {
                // 未验证：提示去验证 + 提供重新发送
                await MainActor.run {
                    isLoading = false
                    errorMessage = "請先驗證您的電子郵件地址"
                    showEmailVerification = true
                }
                return
            }
            
            // 4. 已验证：继续登录流程
            await handlePostLogin()
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = getErrorMessage(from: error)
                isLoading = false
            }
            print("❌ 登入失敗：\(error)")
        }
    }
    
    /// 处理忘记密码
    private func handleForgotPassword() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await viewModel.sendPasswordReset()
            await MainActor.run {
                isLoading = false
                errorMessage = "密碼重置郵件已發送，請檢查您的電子郵件"
            }
            print("✅ 密碼重置郵件已發送")
        } catch {
            await MainActor.run {
                errorMessage = getErrorMessage(from: error)
                isLoading = false
            }
            print("❌ 發送密碼重置郵件失敗：\(error)")
        }
    }
    
    private func getErrorMessage(from error: Error) -> String {
        if let nsError = error as NSError? {
            switch nsError.code {
            case 17008: // FIRAuthErrorCodeInvalidEmail
                return "電子郵件格式不正確"
            case 17009: // FIRAuthErrorCodeWrongPassword
                return "密碼錯誤"
            case 17007: // FIRAuthErrorCodeUserNotFound
                return "找不到此用戶，請先註冊"
            case 17026: // FIRAuthErrorCodeWeakPassword
                return "密碼太弱，請使用至少6個字符"
            case 17020: // FIRAuthErrorCodeNetworkError
                return "網路錯誤，請檢查網路連線"
            case 17010: // FIRAuthErrorCodeTooManyRequests
                return "請求過多，請稍後再試"
            case 17025: // FIRAuthErrorCodeEmailAlreadyInUse
                return "此電子郵件已被使用"
            default:
                return "登入失敗：\(error.localizedDescription)"
            }
        }
        return "登入失敗：\(error.localizedDescription)"
    }
    
    private func handlePostLogin() async {
        guard let authUser = try? AuthenticationManager.shared.getAuthenticatedUser() else {
            print("Email登入：無法獲取認證用戶")
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        print("Email登入成功，用戶ID：\(authUser.uid)")
        
        // 強制刷新 User 狀態
        FirebaseUserManager.shared.refresh()
        
        // 等待一下，確保用戶資料已創建
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 檢查是否需要填寫基本資料
        await checkAndShowBasicInfoIfNeeded(userId: authUser.uid)
    }
    
    private func checkAndShowBasicInfoIfNeeded(userId: String) async {
        do {
            let needsBasicInfo = try await UserManager.shared.needsBasicInfo(userId: userId)
            
            print("Email登入：檢查基本資料，需要填寫：\(needsBasicInfo)")
            
            await MainActor.run {
                isLoading = false
                if needsBasicInfo {
                    print("Email登入：顯示基本資料頁面")
                    showBasicInfo = true
                } else {
                    print("Email登入：基本資料已完成，關閉登入視圖")
                    // 先dismiss当前页面，然后关闭登录视图
                    dismiss()
                }
            }
            
            // 如果不需要填写基本资料，等待一下确保dismiss完成，然后关闭登录视图
            if !needsBasicInfo {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                await MainActor.run {
                    withAnimation {
                        showSignInView = false
                    }
                }
            }
        } catch {
            print("檢查基本資料狀態失敗：\(error)")
            await MainActor.run {
                isLoading = false
                // 發生錯誤時，仍然顯示基本資料頁面，確保用戶可以填寫
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
                    dismiss()
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


#Preview {
    SignInEmailView(showSignInView: .constant(false))
}
