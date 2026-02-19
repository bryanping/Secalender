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
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // 顶部间距
                    Spacer()
                        .frame(height: 20)
                    
                    // 标题区域
                    VStack(spacing: 8) {
                        Text(isSignUpMode ? "signin.create_account".localized() : "signin.welcome_back".localized())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.top, 40)
                        
                        Text(isSignUpMode ? "signin.create_subtitle".localized() : "signin.welcome_subtitle".localized())
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 40)
                    
                    // 输入字段区域
                    VStack(spacing: 24) {
                        // 用户名字段（仅注册模式）
                        if isSignUpMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("signin.username".localized())
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                
                                ZStack(alignment: .leading) {
                                    if viewModel.displayName.isEmpty {
                                        Text("signin.username_placeholder".localized())
                                            .font(.system(size: 16))
                                            .foregroundColor(Color.gray.opacity(0.6))
                                    }
                                    TextField("", text: $viewModel.displayName)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                        .autocapitalization(.none)
                                        .tint(.blue)
                                        .disabled(isLoading)
                                }
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                            }
                        }
                        
                        // 电子邮箱字段
                        VStack(alignment: .leading, spacing: 8) {
                            Text("signin.email".localized())
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            ZStack(alignment: .leading) {
                                if viewModel.email.isEmpty {
                                    Text("signin.email_placeholder".localized())
                                        .font(.system(size: 16))
                                        .foregroundColor(Color.gray.opacity(0.6))
                                }
                                TextField("", text: $viewModel.email)
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .tint(.blue)
                                    .disabled(isLoading)
                            }
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                        }
                        
                        // 密码字段
                        VStack(alignment: .leading, spacing: 8) {
                            Text("signin.password".localized())
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            HStack {
                                if showPassword {
                                    TextField(isSignUpMode ? "signin.password_set_placeholder".localized() : "signin.password_placeholder".localized(), text: $viewModel.password)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                        .autocapitalization(.none)
                                        .disabled(isLoading)
                                } else {
                                    SecureField(isSignUpMode ? "signin.password_set_placeholder".localized() : "signin.password_placeholder".localized(), text: $viewModel.password)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                        .autocapitalization(.none)
                                        .disabled(isLoading)
                                }
                                
                                Button {
                                    withAnimation {
                                        showPassword.toggle()
                                    }
                                } label: {
                                    Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16))
                                }
                            }
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                        }
                        
                        // 确认密码字段（仅注册模式）
                        if isSignUpMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("signin.confirm_password".localized())
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                                
                                HStack {
                                    if showConfirmPassword {
                                        TextField("signin.confirm_password_placeholder".localized(), text: $viewModel.confirmPassword)
                                            .font(.system(size: 16))
                                            .foregroundColor(.black)
                                            .autocapitalization(.none)
                                            .disabled(isLoading)
                                    } else {
                                        SecureField("signin.confirm_password_placeholder".localized(), text: $viewModel.confirmPassword)
                                            .font(.system(size: 16))
                                            .foregroundColor(.black)
                                            .autocapitalization(.none)
                                            .disabled(isLoading)
                                    }
                                    
                                    Button {
                                        withAnimation {
                                            showConfirmPassword.toggle()
                                        }
                                    } label: {
                                        Image(systemName: showConfirmPassword ? "eye.fill" : "eye.slash.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 16))
                                    }
                                }
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // 忘记密码链接（仅登录模式）
                    if !isSignUpMode {
                        HStack {
                            Spacer()
                            Button {
                                showForgotPassword = true
                            } label: {
                                Text("signin.forgot_password".localized())
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.blue)
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                        }
                    }
                    
                    // 错误消息
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
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
                            Text(isSignUpMode ? "signin.register".localized() : "signin.login".localized())
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(isLoading ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty || (isSignUpMode && viewModel.confirmPassword.isEmpty))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    // 切换登录/注册模式
                    HStack(spacing: 4) {
                        Text(isSignUpMode ? "signin.has_account".localized() : "signin.no_account".localized())
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                        
                        Button {
                            withAnimation {
                                isSignUpMode.toggle()
                                errorMessage = nil
                                viewModel.confirmPassword = ""
                                viewModel.displayName = ""
                            }
                        } label: {
                            Text(isSignUpMode ? "signin.login_now".localized() : "signin.register_now".localized())
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.bottom, 40)
                    
                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .font(.system(size: 18, weight: .medium))
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
        .sheet(isPresented: $showEmailVerification) {
            EmailVerificationView(
                isPresented: $showEmailVerification,
                showSignInView: $showSignInView,
                email: viewModel.email
            )
        }
        .alert("signin.forgot_password_title".localized(), isPresented: $showForgotPassword) {
            TextField("signin.enter_email".localized(), text: $viewModel.email)
            Button("common.cancel".localized(), role: .cancel) { }
            Button("signin.send".localized()) {
                Task {
                    await handleForgotPassword()
                }
            }
        } message: {
            Text("signin.forgot_password_message".localized())
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
                    errorMessage = "signin.email_not_verified".localized()
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
                errorMessage = "signin.password_reset_sent".localized()
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
                return "signin.error.invalid_email".localized()
            case 17009: // FIRAuthErrorCodeWrongPassword
                return "signin.error.wrong_password".localized()
            case 17007: // FIRAuthErrorCodeUserNotFound
                return "signin.error.user_not_found".localized()
            case 17026: // FIRAuthErrorCodeWeakPassword
                return "signin.error.weak_password".localized()
            case 17020: // FIRAuthErrorCodeNetworkError
                return "signin.error.network_error".localized()
            case 17010: // FIRAuthErrorCodeTooManyRequests
                return "signin.error.too_many_requests".localized()
            case 17025: // FIRAuthErrorCodeEmailAlreadyInUse
                return "signin.error.email_in_use".localized()
            default:
                return "signin.error.login_failed".localized(with: error.localizedDescription)
            }
        }
        return "signin.error.login_failed".localized(with: error.localizedDescription)
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
