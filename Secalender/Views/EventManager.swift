//
//  EventManager.swift
//  Secalender
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import SwiftUI // 用于获取环境对象

// 导入必要的模型和管理器
// 导入用户管理器
// 导入缓存管理器

class EventManager {
    static let shared = EventManager()
    private init() {}

    private let db = Firestore.firestore()

    /// 新增活动
    func addEvent(event: Event) async throws {
        var newEvent = event
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        newEvent.createTime = formatter.string(from: now)
        
        // 保存到 Firestore - 添加 await
        let docRef = try await db.collection("events").addDocument(from: newEvent)
        
        // 获取生成的文档ID并转换为Int（使用哈希值）
        let documentId = docRef.documentID
        let intId = abs(documentId.hashValue)
        
        // 更新事件的ID
        newEvent.id = intId
        try await db.collection("events").document(documentId).setData(from: newEvent, merge: true)
        
        // 清除缓存，确保下次获取最新数据
        // 缓存已移除
    }

    /// 更新活动
    func updateEvent(event: Event) async throws {
        guard let eventId = event.id else {
            throw NSError(domain: "EventManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "活动ID不存在"])
        }

        // 不修改createTime，保持原始创建时间
        let updatedEvent = event

        // 查找具有匹配ID的文档
        let snapshot = try await db.collection("events")
            .whereField("id", isEqualTo: eventId)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            throw NSError(domain: "EventManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到要更新的活动"])
        }
        
        // 使用找到的文档ID进行更新
        try await db.collection("events").document(document.documentID).setData(from: updatedEvent, merge: true)
        
        print("活动更新成功: ID \(eventId)")
        
        // 清除缓存，确保下次获取最新数据
        // 缓存已移除
    }

    /// 读取所有活动
    func fetchEvents() async throws -> [Event] {
        let snapshot = try await db.collection("events").getDocuments()
        return snapshot.documents.compactMap { document in
            do {
                var event = try document.data(as: Event.self)
                // 如果事件没有ID，使用文档ID的哈希值
                if event.id == nil {
                    event.id = abs(document.documentID.hashValue)
                }
                return event
            } catch {
                print("解析事件失败: \(error)")
                return nil
            }
        }
    }
    
    /// 删除活动
    func deleteEvent(eventId: Int) async throws {
        print("尝试删除活动，ID: \(eventId)")
        
        // 查找具有匹配ID的文档
        let snapshot = try await db.collection("events")
            .whereField("id", isEqualTo: eventId)
            .getDocuments()
        
        print("查询结果：找到 \(snapshot.documents.count) 个文档")
        
        // 如果通过ID查找失败，尝试通过文档ID的哈希值查找
        if snapshot.documents.isEmpty {
            let allSnapshot = try await db.collection("events").getDocuments()
            for document in allSnapshot.documents {
                let documentHashId = abs(document.documentID.hashValue)
                if documentHashId == eventId {
                    print("通过文档ID哈希值找到匹配的活动")
                    try await db.collection("events").document(document.documentID).delete()
                    print("活动删除成功: ID \(eventId)")
                    return
                }
            }
        } else {
            // 使用找到的文档ID进行删除
            let document = snapshot.documents.first!
            try await db.collection("events").document(document.documentID).delete()
            print("活动删除成功: ID \(eventId)")
            return
        }
        
        throw NSError(domain: "EventManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到要删除的活动"])
    }
    
    /// 分享活动给好友
    func shareEventWithFriends(eventId: Int, friendIds: [String], senderId: String? = nil) async throws {
        guard !friendIds.isEmpty else { return }
        
        // 确定发送者ID
        let senderUserId: String
        if let senderId = senderId, !senderId.isEmpty {
            senderUserId = senderId
        } else if let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty {
            senderUserId = currentUserId
        } else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        let batch = db.batch()
        let timestamp = FieldValue.serverTimestamp()
        
        for friendId in friendIds {
            // 创建分享记录
            let shareRef = db.collection("event_shares").document()
            batch.setData([
                "eventId": eventId,
                "senderId": senderUserId,
                "receiverId": friendId,
                "sharedAt": timestamp,
                "status": "shared"
            ], forDocument: shareRef)
            
            // 创建通知
            let notificationRef = db.collection("notifications").document()
            batch.setData([
                "id": notificationRef.documentID,
                "eventId": eventId,
                "senderId": senderUserId,
                "receiverId": friendId,
                "type": "event_shared",
                "createdAt": timestamp,
                "isRead": false,
                "status": "pending"
            ], forDocument: notificationRef)
        }
        
        try await batch.commit()
    }
    
    /// 邀请好友参加活动
    func inviteFriendsToEvent(eventId: Int, friendIds: [String], senderId: String? = nil) async throws {
        guard !friendIds.isEmpty else { return }
        
        // 确定发送者ID
        let senderUserId: String
        if let senderId = senderId, !senderId.isEmpty {
            senderUserId = senderId
        } else if let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty {
            senderUserId = currentUserId
        } else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        let batch = db.batch()
        let timestamp = FieldValue.serverTimestamp()
        
        for friendId in friendIds {
            // 创建邀请记录
            let invitationRef = db.collection("event_invitations").document()
            batch.setData([
                "eventId": eventId,
                "senderId": senderUserId,
                "receiverId": friendId,
                "invitedAt": timestamp,
                "status": "pending"
            ], forDocument: invitationRef)
            
            // 创建通知
            let notificationRef = db.collection("notifications").document()
            batch.setData([
                "id": notificationRef.documentID,
                "eventId": eventId,
                "senderId": senderUserId,
                "receiverId": friendId,
                "type": "event_invitation",
                "createdAt": timestamp,
                "isRead": false,
                "status": "pending"
            ], forDocument: notificationRef)
        }
        
        try await batch.commit()
    }
    
    /// 获取用户的通知
    func fetchNotifications(for userId: String) async throws -> [NotificationEntry] {
        let snapshot = try await db.collection("notifications")
            .whereField("receiverId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> NotificationEntry? in
            let data = doc.data()
            
            guard let id = doc.documentID as String?,
                  let eventId = data["eventId"] as? Int,
                  let senderId = data["senderId"] as? String,
                  let receiverId = data["receiverId"] as? String,
                  let type = data["type"] as? String,
                  let isRead = data["isRead"] as? Bool,
                  let status = data["status"] as? String else {
                return nil
            }
            
            // 处理时间戳
            let createdAt: Date
            if let timestamp = data["createdAt"] as? Timestamp {
                createdAt = timestamp.dateValue()
            } else {
                createdAt = Date()
            }
            
            return NotificationEntry(
                id: id,
                eventId: eventId,
                senderId: senderId,
                receiverId: receiverId,
                type: type,
                createdAt: createdAt,
                isRead: isRead,
                status: status
            )
        }
    }
    
    /// 标记通知为已读
    func markNotificationAsRead(notificationId: String) async throws {
        try await db.collection("notifications")
            .document(notificationId)
            .updateData(["isRead": true])
    }
    
    /// 响应活动邀请
    func respondToInvitation(notificationId: String, status: String) async throws {
        // 更新通知状态
        try await db.collection("notifications")
            .document(notificationId)
            .updateData([
                "isRead": true,
                "status": status
            ])
        
        // 同时更新邀请记录
        let notificationSnapshot = try await db.collection("notifications")
            .document(notificationId)
            .getDocument()
        
        guard let notificationData = notificationSnapshot.data(),
              let eventId = notificationData["eventId"] as? Int,
              let senderId = notificationData["senderId"] as? String,
              let receiverId = notificationData["receiverId"] as? String else {
            throw NSError(domain: "EventManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到通知信息"])
        }
        
        // 查找并更新对应的邀请记录
        let invitationsSnapshot = try await db.collection("event_invitations")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("senderId", isEqualTo: senderId)
            .whereField("receiverId", isEqualTo: receiverId)
            .getDocuments()
        
        for doc in invitationsSnapshot.documents {
            try await db.collection("event_invitations")
                .document(doc.documentID)
                .updateData(["status": status])
        }
    }
}

// 通知条目结构
struct NotificationEntry: Identifiable {
    let id: String
    let eventId: Int
    let senderId: String
    let receiverId: String
    let type: String
    let createdAt: Date
    let isRead: Bool
    let status: String // 用于邀请状态
}
