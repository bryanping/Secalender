//
//  FriendInviteLinkManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import FirebaseFirestore

/// 好友邀请链接管理器
final class FriendInviteLinkManager {
    static let shared = FriendInviteLinkManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    /// 生成好友邀请链接
    /// - Parameter userId: 用户ID
    /// - Parameter userCode: 用户8位代码（可选，用于二维码）
    /// - Returns: 邀请链接
    func generateFriendInviteLink(userId: String, userCode: String?) async throws -> String {
        // 创建邀请记录
        let inviteRef = db.collection("friend_invites").document()
        let inviteData: [String: Any] = [
            "userId": userId,
            "userCode": userCode ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
            "isActive": true
        ]
        
        try await inviteRef.setData(inviteData)
        
        // 生成邀请链接（使用文档ID作为唯一标识）
        let inviteCode = inviteRef.documentID
        let inviteLink = "https://secalender.app/friend/\(inviteCode)"
        
        return inviteLink
    }
    
    /// 验证好友邀请链接
    /// - Parameter inviteCode: 邀请代码
    /// - Returns: 用户ID，如果无效返回 nil
    func validateFriendInviteLink(inviteCode: String) async throws -> String? {
        let doc = try await db.collection("friend_invites")
            .document(inviteCode)
            .getDocument()
        
        guard let data = doc.data(),
              let userId = data["userId"] as? String,
              let isActive = data["isActive"] as? Bool,
              isActive else {
            return nil
        }
        
        // 检查是否过期
        if let expiresAt = data["expiresAt"] as? Timestamp {
            if expiresAt.dateValue() < Date() {
                return nil
            }
        }
        
        return userId
    }
    
    /// 從 URL 解析好友邀請代碼
    /// 支援格式：https://secalender.app/friend/{code}、secalender://friend/{code}
    /// - Parameter url: 分享連結 URL
    /// - Returns: 邀請代碼，無法解析時回傳 nil
    func parseFriendCode(from url: URL) -> String? {
        let path: String
        if url.scheme == "secalender" {
            path = url.host.map { "\($0)\(url.path)" } ?? url.path
        } else if url.host?.hasSuffix("secalender.app") == true {
            path = url.path
        } else {
            return nil
        }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard trimmed.hasPrefix("friend/") else { return nil }
        let code = String(trimmed.dropFirst(7)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return code.isEmpty ? nil : code
    }
    
    /// 生成好友邀请分享文本
    /// - Parameter inviteLink: 邀请链接
    /// - Returns: 分享文本
    func generateShareText(inviteLink: String) -> String {
        return "📱 邀请你加入 Secalender！\n\n🔗 点击链接添加我为好友：\(inviteLink)"
    }
    
    /// 生成二维码内容（使用 userCode 或 userId）
    /// - Parameter userId: 用户ID
    /// - Parameter userCode: 用户8位代码
    /// - Returns: 二维码内容字符串
    func generateQRCodeContent(userId: String, userCode: String?) -> String {
        // 优先使用 userCode，如果没有则使用 userId
        if let code = userCode, !code.isEmpty {
            return "secalender://friend/\(code)"
        } else {
            return "secalender://friend/\(userId)"
        }
    }
}
