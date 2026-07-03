//
//  EmailVerificationView.swift
//  Secalender
//
//  Created by linping on 2025/1/XX.
//

import SwiftUI
import FirebaseAuth

@MainActor
struct EmailVerificationView: View {
    @Binding var isPresented: Bool
    @Binding var showSignInView: Bool
    let email: String
    
    @StateObject private var viewModel = SignInEmailViewModel()
    @State private var isResending: Bool = false
    @State private var resendSuccess: Bool = false
    @State private var resendError: String?
    @State private var isChecking: Bool = false
    @State private var isVerified: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // 图标
                Image(systemName: "envelope.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)
                
                // 标题
                Text("請檢查您的電子郵件")
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                
                // 说明文字
                VStack(spacing: 8) {
                    Text("我們已向以下地址發送驗證郵件：")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text(email)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
                // 提示文字
                Text("請點擊郵件中的連結以驗證您的帳號")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // 按钮区域
                VStack(spacing: 12) {
                    // 重新發送按钮
                    Button {
                        Task {
                            await handleResendVerification()
                        }
                    } label: {
                        HStack {
                            if isResending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .padding(.trailing, 8)
                            }
                            Text("重新發送驗證郵件")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .disabled(isResending || isChecking)
                    
                    // 檢查驗證狀態按钮
                    Button {
                        Task {
                            await handleCheckVerification()
                        }
                    } label: {
                        HStack {
                            if isChecking {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            }
                            Text("我已驗證，繼續")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isChecking ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(isChecking || isResending)
                    
                    // 改信箱按钮
                    Button {
                        isPresented = false
                    } label: {
                        Text("更改電子郵件地址")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                    
                    // 登出按钮
                    Button {
                        Task {
                            await handleSignOut()
                        }
                    } label: {
                        Text("登出")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                
                // 成功/错误消息
                if resendSuccess {
                    Text("驗證郵件已重新發送！")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                        .padding(.horizontal)
                }
                
                if let resendError = resendError {
                    Text(resendError)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("驗證電子郵件")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func handleResendVerification() async {
        isResending = true
        resendSuccess = false
        resendError = nil
        
        do {
            viewModel.email = email
            try await viewModel.sendEmailVerification()
            resendSuccess = true
            print("✅ 驗證郵件已重新發送")
        } catch {
            resendError = getErrorMessage(from: error)
            print("❌ 重新發送失敗：\(error)")
        }
        
        isResending = false
    }
    
    private func handleCheckVerification() async {
        isChecking = true
        resendError = nil
        
        do {
            // 重新加载用户信息以获取最新的验证状态
            try await viewModel.reloadUser()
            
            // 检查是否已验证
            let verified = try viewModel.isEmailVerified()
            
            if verified {
                isVerified = true
                print("✅ 郵箱已驗證")
                // 关闭验证页面，继续登录流程
                isPresented = false
                // 触发后续登录流程
                await handlePostVerification()
            } else {
                resendError = "郵箱尚未驗證，請檢查您的郵件"
            }
        } catch {
            resendError = getErrorMessage(from: error)
            print("❌ 檢查驗證狀態失敗：\(error)")
        }
        
        isChecking = false
    }
    
    private func handlePostVerification() async {
        // 这里可以触发后续流程，比如检查基本资料等
        // 由于用户已经登录，可以直接关闭登录视图
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        FirebaseUserManager.shared.refresh()
        
        // 检查是否需要填写基本资料
        guard let authUser = try? AuthenticationManager.shared.getAuthenticatedUser() else {
            return
        }
        
        do {
            let needsBasicInfo = try await UserManager.shared.needsBasicInfo(userId: authUser.uid)
            if !needsBasicInfo {
                await MainActor.run {
                    withAnimation {
                        showSignInView = false
                    }
                }
            }
        } catch {
            print("檢查基本資料失敗：\(error)")
        }
    }
    
    private func handleSignOut() async {
        do {
            try AuthenticationManager.shared.signOut()
            isPresented = false
            await MainActor.run {
                withAnimation {
                    showSignInView = true
                }
            }
        } catch {
            print("登出失敗：\(error)")
        }
    }
    
    private func getErrorMessage(from error: Error) -> String {
        if let nsError = error as NSError? {
            switch nsError.code {
            case 17020: // FIRAuthErrorCodeNetworkError
                return "網路錯誤，請檢查網路連線"
            case 17010: // FIRAuthErrorCodeTooManyRequests
                return "請求過多，請稍後再試"
            default:
                return "操作失敗：\(error.localizedDescription)"
            }
        }
        return "操作失敗：\(error.localizedDescription)"
    }
}

#Preview {
    EmailVerificationView(
        isPresented: .constant(true),
        showSignInView: .constant(true),
        email: "example@email.com"
    )
}
