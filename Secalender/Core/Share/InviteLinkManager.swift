//
//  InviteLinkManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import FirebaseFirestore

/// 邀请链接管理器
final class InviteLinkManager {
    static let shared = InviteLinkManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    /// 生成活动邀请链接
    func generateEventInviteLink(eventId: Int, eventTitle: String, creatorId: String) async throws -> String {
        // 创建邀请记录
        let inviteRef = db.collection("event_invites").document()
        let inviteData: [String: Any] = [
            "eventId": eventId,
            "eventTitle": eventTitle,
            "creatorId": creatorId,
            "createdAt": FieldValue.serverTimestamp(),
            "expiresAt": Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
            "isActive": true
        ]
        
        try await inviteRef.setData(inviteData)
        
        // 生成短链接（这里使用文档ID作为唯一标识）
        let inviteCode = inviteRef.documentID
        let inviteLink = "https://secalender.app/invite/\(inviteCode)"
        
        return inviteLink
    }
    
    /// 验证邀请链接
    func validateInviteLink(inviteCode: String) async throws -> (eventId: Int, eventTitle: String, creatorId: String)? {
        let doc = try await db.collection("event_invites")
            .document(inviteCode)
            .getDocument()
        
        guard let data = doc.data(),
              let eventId = data["eventId"] as? Int,
              let eventTitle = data["eventTitle"] as? String,
              let creatorId = data["creatorId"] as? String,
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
        
        return (eventId, eventTitle, creatorId)
    }
    
    /// 從 URL 解析邀請代碼
    /// 支援格式：https://secalender.app/invite/{code}、secalender://invite/{code}
    /// - Parameter url: 分享連結 URL
    /// - Returns: 邀請代碼，無法解析時回傳 nil
    func parseInviteCode(from url: URL) -> String? {
        let path: String
        if url.scheme == "secalender" {
            path = url.host.map { "\($0)\(url.path)" } ?? url.path
        } else if url.host?.hasSuffix("secalender.app") == true {
            path = url.path
        } else {
            return nil
        }
        // /invite/{code} 或 invite/{code}
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard trimmed.hasPrefix("invite/") else { return nil }
        let code = String(trimmed.dropFirst(7)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return code.isEmpty ? nil : code
    }
    
    /// 生成分享文本
    func generateShareText(event: Event, inviteLink: String) -> String {
        var text = "📅 邀请你参加活动：\(event.title)\n\n"
        
        if event.isAllDay ?? false {
            text += "📆 日期：\(event.date)\n"
            if let endDate = event.endDate, endDate != event.date {
                text += "📆 结束日期：\(endDate)\n"
            }
            text += "⏰ 全天事件\n"
        } else {
            text += "📆 日期：\(event.date)\n"
            text += "⏰ 时间：\(event.startTime) - \(event.endTime)\n"
        }
        
        if !event.destination.isEmpty {
            text += "📍 地点：\(event.destination)\n"
        }
        
        if let info = event.information, !info.isEmpty {
            text += "\n📝 \(info)\n"
        }
        
        text += "\n🔗 点击链接查看详情：\(inviteLink)"
        
        return text
    }
}
