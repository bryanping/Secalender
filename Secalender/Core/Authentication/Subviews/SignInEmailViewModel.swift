//
//  SignInEmailViewModel.swift
//  Secalender
//
//  Created by linping on 2024/7/1.
//

import Foundation


@MainActor
final class SignInEmailViewModel: ObservableObject {
    
    @Published var email = ""
    @Published var password = ""
    
    func signUp() async throws {
        guard !email.isEmpty, !password.isEmpty else {
            print("No email or password found.")
            return
        }
        
        let authDataResult = try await AuthenticationManager.shared.createUser(email: email, password: password)
        // Email 註冊沒有 provider 姓名
        try await UserManager.shared.createNewUser(auth: authDataResult, providerName: nil, providerType: "email")
    }
    func signIn() async throws {
        guard !email.isEmpty, !password.isEmpty else {
            throw NSError(domain: "SignInError", code: 400, userInfo: [NSLocalizedDescriptionKey: "請輸入電子郵件和密碼"])
        }
        
        let authDataResult = try await AuthenticationManager.shared.signInUser(email: email, password: password)
        
        // 確保用戶資料存在（如果不存在則創建）
        do {
            try await UserManager.shared.createNewUser(auth: authDataResult, providerName: nil, providerType: "email")
        } catch {
            // 如果用戶已存在，這是正常的，不需要處理
            print("用戶資料已存在或創建失敗：\(error)")
        }
    }
    
    /// 发送邮箱验证邮件
    func sendEmailVerification() async throws {
        try await AuthenticationManager.shared.sendEmailVerification()
    }
    
    /// 重新加载用户信息（用于检查邮箱验证状态）
    func reloadUser() async throws {
        try await AuthenticationManager.shared.reloadUser()
    }
    
    /// 检查邮箱是否已验证
    func isEmailVerified() throws -> Bool {
        return try AuthenticationManager.shared.isEmailVerified()
    }
    
    /// 发送密码重置邮件
    func sendPasswordReset() async throws {
        guard !email.isEmpty else {
            throw NSError(domain: "PasswordResetError", code: 400, userInfo: [NSLocalizedDescriptionKey: "請輸入電子郵件"])
        }
        try await AuthenticationManager.shared.resetPassword(email: email)
    }
}
