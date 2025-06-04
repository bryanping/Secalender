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
}
