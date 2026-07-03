//
//  AuthenticationViewModel.swift
//  Secalender
//
//  Created by linping on 2024/7/1.
//

import Foundation

@MainActor
final class AuthenticationViewModel: ObservableObject {

    func signInGoogle() async throws {
        let helper = SignInGoogleHelper()
        let tokens = try await helper.signIn()
        let authDataResult = try await AuthenticationManager.shared.signInWithGoogle(tokens: tokens)
        // 傳遞 Google 提供的姓名（通常每次都能拿到）
        try await UserManager.shared.createNewUser(auth: authDataResult, providerName: tokens.name, providerType: "google")
    }
    
    func signInApple() async throws {
        let helper = SignInAppleHelper()
        let tokens = try await helper.startSignInWithAppleFlow()
        let authDataResult = try await AuthenticationManager.shared.signInWithApple(tokens: tokens)
        // 傳遞 Apple 提供的姓名（只在第一次授權時可能拿到）
        try await UserManager.shared.createNewUser(auth: authDataResult, providerName: tokens.name, providerType: "apple")
    }
    
    func signInAnonymous() async throws {
        let authDataResult = try await AuthenticationManager.shared.signInAnonymous()
        // 匿名登入沒有 provider 姓名
        try await UserManager.shared.createNewUser(auth: authDataResult, providerName: nil, providerType: "anonymous")
    }
}  
