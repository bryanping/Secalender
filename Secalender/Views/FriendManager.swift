//
//  FriendManager.swift
//  Secalender
//
//  Created by 林平 on 2025/6/10.
//

//
//  FriendManager.swift
//  Secalender
//
//  Created by 林平 on 2025/6/10.
//

import Foundation
import Firebase

// MARK: - FriendEntry 数据模型
/// 好友条目数据模型，统一管理好友信息
struct FriendEntry: Identifiable, Equatable {
    let id: String
    let alias: String?
    let name: String?
    let email: String?
    let photoUrl: String?
    let gender: String?
    
    /// 可选的选择状态，用于多选场景
    var isSelected: Bool = false
    
    static func == (lhs: FriendEntry, rhs: FriendEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FriendManager
final class FriendManager {
    static let shared = FriendManager()
    private init() {}

    private var friendIds: Set<String> = []

    /// 初始化读取当前使用者的好友清单（建议在登入后调用一次）
    func loadFriends(for userId: String) async {
        let db = Firestore.firestore()
        do {
            // 从friends集合中获取当前用户的好友列表
            let snapshot = try await db.collection("friends")
                .whereField("owner", isEqualTo: userId)
                .getDocuments()
            
            // 提取好友ID
            self.friendIds = Set(snapshot.documents.compactMap { $0["friend"] as? String })
        } catch {
            print("读取好友失败：\(error.localizedDescription)")
        }
    }

    /// 判断是否为好友
    func isFriend(with userId: String) -> Bool {
        return friendIds.contains(userId)
    }
    
    /// 获取好友ID集合
    func getFriendIds() -> Set<String> {
        return friendIds
    }

    /// 添加好友（只写入 owner、friend、since、备注名与电话）
    func addFriend(
        currentUserId: String,
        targetUserId: String,
        remarksName: String? = nil,
        remarksPhone: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let db = Firestore.firestore()
        
        // 创建一个新的好友记录
        var data: [String: Any] = [
            "owner": currentUserId,
            "friend": targetUserId,
            "since": FieldValue.serverTimestamp()
        ]
        if let name = remarksName { data["remarksname"] = name }
        if let phone = remarksPhone { data["remarkphone"] = phone }

        // 添加到friends集合
        db.collection("friends").addDocument(data: data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                self.friendIds.insert(targetUserId)
                completion(.success(()))
            }
        }
    }
    /// 删除好友关系
    func removeFriend(currentUserId: String, targetUserId: String) async throws {
        let db = Firestore.firestore()
        
        // 查找对应的好友记录
        let snapshot = try await db.collection("friends")
            .whereField("owner", isEqualTo: currentUserId)
            .whereField("friend", isEqualTo: targetUserId)
            .getDocuments()
        
        // 删除找到的所有记录
        for document in snapshot.documents {
            try await document.reference.delete()
        }
        
        // 从本地缓存中移除
        self.friendIds.remove(targetUserId)
    }
    
    // MARK: - 好友请求相关方法
    
    /// 发送好友请求
    func sendFriendRequest(
        from currentUserId: String,
        to targetUserId: String,
        message: String? = nil
    ) async throws {
        let db = Firestore.firestore()
        
        // 检查是否已经是好友
        let existingFriend = try await db.collection("friends")
            .whereField("owner", isEqualTo: currentUserId)
            .whereField("friend", isEqualTo: targetUserId)
            .getDocuments()
        
        if !existingFriend.documents.isEmpty {
            throw NSError(domain: "AlreadyFriends", code: 400, userInfo: [NSLocalizedDescriptionKey: "已经是好友"])
        }
        
        // 检查是否已有待处理的请求
        let existingRequest = try await db.collection("friend_requests")
            .whereField("from", isEqualTo: currentUserId)
            .whereField("to", isEqualTo: targetUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        if !existingRequest.documents.isEmpty {
            throw NSError(domain: "RequestAlreadySent", code: 400, userInfo: [NSLocalizedDescriptionKey: "已发送过好友请求，请等待对方审核"])
        }
        
        // 检查对方是否已发送请求给自己
        let reverseRequest = try await db.collection("friend_requests")
            .whereField("from", isEqualTo: targetUserId)
            .whereField("to", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        if !reverseRequest.documents.isEmpty {
            throw NSError(domain: "RequestAlreadyReceived", code: 400, userInfo: [NSLocalizedDescriptionKey: "对方已发送好友请求，请前往审核"])
        }
        
        // 创建好友请求
        var requestData: [String: Any] = [
            "from": currentUserId,
            "to": targetUserId,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        if let message = message {
            requestData["message"] = message
        }
        
        let docRef = try await db.collection("friend_requests").addDocument(data: requestData)
        print("✅ 好友请求已发送: 从 \(currentUserId) 到 \(targetUserId), 文档ID: \(docRef.documentID)")
    }
    
    /// 获取收到的好友请求列表
    func getReceivedFriendRequests(for userId: String) async throws -> [QueryDocumentSnapshot] {
        let db = Firestore.firestore()
        // 先查询，然后在客户端排序（避免需要 Firestore 复合索引）
        let snapshot = try await db.collection("friend_requests")
            .whereField("to", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        // 在客户端按创建时间排序
        let sortedDocuments = snapshot.documents.sorted { doc1, doc2 in
            let date1 = (doc1.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let date2 = (doc2.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            return date1 > date2 // 降序排列
        }
        
        return sortedDocuments
    }
    
    /// 获取发送的好友请求列表
    func getSentFriendRequests(for userId: String) async throws -> [QueryDocumentSnapshot] {
        let db = Firestore.firestore()
        // 先查询，然后在客户端排序（避免需要 Firestore 复合索引）
        let snapshot = try await db.collection("friend_requests")
            .whereField("from", isEqualTo: userId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        // 在客户端按创建时间排序
        let sortedDocuments = snapshot.documents.sorted { doc1, doc2 in
            let date1 = (doc1.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            let date2 = (doc2.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
            return date1 > date2 // 降序排列
        }
        
        return sortedDocuments
    }
    
    /// 接受好友请求（双向添加好友）
    func acceptFriendRequest(
        requestId: String,
        from senderId: String,
        to receiverId: String
    ) async throws {
        let db = Firestore.firestore()
        
        // 使用批处理确保原子性
        let batch = db.batch()
        
        // 1. 更新请求状态为已接受
        let requestRef = db.collection("friend_requests").document(requestId)
        batch.updateData(["status": "accepted"], forDocument: requestRef)
        
        // 2. 添加双向好友关系
        // sender -> receiver
        let friendRef1 = db.collection("friends").document()
        batch.setData([
            "owner": senderId,
            "friend": receiverId,
            "since": FieldValue.serverTimestamp()
        ], forDocument: friendRef1)
        
        // receiver -> sender
        let friendRef2 = db.collection("friends").document()
        batch.setData([
            "owner": receiverId,
            "friend": senderId,
            "since": FieldValue.serverTimestamp()
        ], forDocument: friendRef2)
        
        // 执行批处理
        try await batch.commit()
        
        // 更新本地缓存
        self.friendIds.insert(senderId)
    }
    
    /// 拒绝好友请求
    func rejectFriendRequest(requestId: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("friend_requests").document(requestId).updateData([
            "status": "rejected"
        ])
    }
    
    /// 取消发送的好友请求
    func cancelFriendRequest(requestId: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("friend_requests").document(requestId).updateData([
            "status": "cancelled"
        ])
    }
}
