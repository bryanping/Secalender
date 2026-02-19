//
//  PhoneVerificationManager.swift
//  Secalender
//
//  Created by linping on 2025/1/XX.
//

import Foundation
import FirebaseAuth

final class PhoneVerificationManager {
    static let shared = PhoneVerificationManager()
    private init() {}
    
    private var verificationID: String?
    
    /// 發送驗證碼到手機號
    @MainActor
    func sendVerificationCode(to phoneNumber: String, countryCode: String = "+886") async throws -> String {
        // 格式化手機號（確保包含國家代碼）
        let formattedPhone = formatPhoneNumber(phoneNumber, countryCode: countryCode)
        
        // 使用 Firebase Phone Auth 發送驗證碼
        let provider = PhoneAuthProvider.provider()
        verificationID = try await provider.verifyPhoneNumber(formattedPhone, uiDelegate: nil)
        
        guard let verificationID = verificationID else {
            throw NSError(domain: "PhoneVerificationError", code: 500, userInfo: [NSLocalizedDescriptionKey: "無法獲取驗證 ID"])
        }
        
        return verificationID
    }
    
    /// 驗證驗證碼
    @MainActor
    func verifyCode(_ code: String) async throws {
        guard let verificationID = verificationID else {
            throw NSError(domain: "PhoneVerificationError", code: 400, userInfo: [NSLocalizedDescriptionKey: "請先發送驗證碼"])
        }
        
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
        
        // 如果用戶已登入，則連結手機號；否則登入
        if let currentUser = Auth.auth().currentUser {
            // 連結手機號到現有帳號
            try await currentUser.link(with: credential)
        } else {
            // 使用手機號登入（如果沒有其他登入方式）
            _ = try await Auth.auth().signIn(with: credential)
        }
    }
    
    /// 驗證驗證碼（僅驗證，不連結到帳號）
    /// 注意：此方法會嘗試連結手機號，如果用戶已有手機號可能會失敗
    /// 建議在基本資料填寫時使用，因為此時用戶通常還沒有手機號
    @MainActor
    func verifyCodeOnly(_ code: String) async throws -> Bool {
        guard let verificationID = verificationID else {
            throw NSError(domain: "PhoneVerificationError", code: 400, userInfo: [NSLocalizedDescriptionKey: "請先發送驗證碼"])
        }
        
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: code)
        
        // 嘗試連結到當前用戶（如果驗證碼正確會成功）
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "PhoneVerificationError", code: 401, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"])
        }
        
        do {
            // 嘗試連結（如果驗證碼正確，會成功；如果錯誤，會拋出錯誤）
            _ = try await currentUser.link(with: credential)
            return true
        } catch {
            // 如果錯誤是因為手機號已存在，也算驗證成功
            if let authError = error as NSError?,
               authError.code == 17025 { // FIRAuthErrorCodeCredentialAlreadyInUse
                return true
            }
            throw error
        }
    }
    
    /// 格式化手機號（添加國家代碼）
    private func formatPhoneNumber(_ phoneNumber: String, countryCode: String) -> String {
        var formatted = phoneNumber.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        // 如果已經有國家代碼，直接返回
        if formatted.hasPrefix(countryCode) {
            return formatted
        }
        
        // 如果已經有其他國家代碼（以 + 開頭），直接返回
        if formatted.hasPrefix("+") {
            return formatted
        }
        
        // 處理台灣號碼（以 0 開頭）
        if countryCode == "+886" && formatted.hasPrefix("0") {
            formatted = countryCode + String(formatted.dropFirst())
        } else {
            // 其他國家，直接添加國家代碼
            formatted = countryCode + formatted
        }
        
        return formatted
    }
    
    /// 清除驗證 ID（用於重新發送）
    func clearVerificationID() {
        verificationID = nil
    }
}
