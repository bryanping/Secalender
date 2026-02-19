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
struct FriendEntry: Identifiable, Equatable, Codable {
    let id: String
    let alias: String?
    let name: String?
    let email: String?
    let photoUrl: String?
    let gender: String?
    
    /// 可选的选择状态，用于多选场景（不参与编码）
    var isSelected: Bool = false
    
    // Codable 支持：排除 isSelected 字段
    enum CodingKeys: String, CodingKey {
        case id, alias, name, email, photoUrl, gender
    }
    
    static func == (lhs: FriendEntry, rhs: FriendEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FriendManager
final class FriendManager {
    static let shared = FriendManager()
    private init() {}

    private var friendIds: Set<String> = []
    private var cachedFriends: [FriendEntry] = []
    private var isLoadingFriends = false
    private let cacheManager = FriendCacheManager.shared
    
    // MARK: - 朋友名单加载（带缓存）
    
    /// 获取朋友名单（优先从缓存读取，参考微信做法）
    /// - Parameter userId: 用户ID
    /// - Parameter forceRefresh: 是否强制刷新（忽略缓存）
    /// - Returns: 朋友名单
    func getFriends(for userId: String, forceRefresh: Bool = false) async -> [FriendEntry] {
        // 如果正在加载，返回当前缓存
        if isLoadingFriends {
            return cachedFriends.isEmpty ? cacheManager.loadFriends(for: userId) : cachedFriends
        }
        
        // 1. 优先从内存缓存读取
        if !cachedFriends.isEmpty && !forceRefresh {
            print("📦 从内存缓存返回 \(cachedFriends.count) 个朋友")
            // 后台异步更新（不阻塞）
            Task.detached(priority: .background) { [weak self] in
                await self?.refreshFriendsFromFirebase(for: userId)
            }
            return cachedFriends
        }
        
        // 2. 从本地缓存读取
        let localCachedFriends = cacheManager.loadFriends(for: userId)
        if !localCachedFriends.isEmpty && !forceRefresh {
            // 检查缓存是否有效（24小时内）
            if cacheManager.isCacheValid(for: userId, maxAge: 24 * 60 * 60) {
                print("📦 从本地缓存返回 \(localCachedFriends.count) 个朋友")
                cachedFriends = localCachedFriends
                // 后台异步更新（不阻塞）
                Task.detached(priority: .background) { [weak self] in
                    await self?.refreshFriendsFromFirebase(for: userId)
                }
                return localCachedFriends
            } else {
                print("⚠️ 本地缓存已过期，需要刷新")
            }
        }
        
        // 3. 从 Firebase 读取（缓存无效或不存在时）
        return await refreshFriendsFromFirebase(for: userId)
    }
    
    /// 从 Firebase 刷新朋友名单并更新缓存
    private func refreshFriendsFromFirebase(for userId: String) async -> [FriendEntry] {
        guard !isLoadingFriends else {
            return cachedFriends.isEmpty ? cacheManager.loadFriends(for: userId) : cachedFriends
        }
        
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        
        let db = Firestore.firestore()
        
        do {
            // 1. 获取好友ID列表
            let snapshot = try await db.collection("friends")
                .whereField("owner", isEqualTo: userId)
                .getDocuments()
            
            let friendIds = snapshot.documents.compactMap { $0["friend"] as? String }
            print("📋 从 Firebase 加载好友，找到 \(friendIds.count) 个好友ID")
            
            // 更新 friendIds 集合
            self.friendIds = Set(friendIds)
            
            guard !friendIds.isEmpty else {
                cachedFriends = []
                cacheManager.saveFriends([], for: userId)
                return []
            }
            
            // 2. 批量获取好友详细信息
            let loadedFriends = try await fetchUsersByDocumentIds(db: db, userIds: friendIds)
            
            // 3. 更新缓存
            cachedFriends = loadedFriends
            cacheManager.saveFriends(loadedFriends, for: userId)
            
            print("✅ 朋友名单已刷新并缓存: \(loadedFriends.count) 个朋友")
            return loadedFriends
        } catch {
            print("❌ 从 Firebase 刷新朋友名单失败: \(error.localizedDescription)")
            // 失败时返回本地缓存
            let fallbackFriends = cacheManager.loadFriends(for: userId)
            cachedFriends = fallbackFriends
            return fallbackFriends
        }
    }
    
    /// 批量获取用户信息（通过 documentID）
    private func fetchUsersByDocumentIds(db: Firestore, userIds: [String]) async throws -> [FriendEntry] {
        let chunks = userIds.chunked(into: 10) // Firestore in 查询限制为10个
        var results: [FriendEntry] = []
        results.reserveCapacity(userIds.count)
        
        try await withThrowingTaskGroup(of: [FriendEntry].self) { group in
            for chunk in chunks {
                group.addTask {
                    let snapshot = try await db.collection("users")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    
                    return snapshot.documents.compactMap { doc in
                        let data = doc.data()
                        return FriendEntry(
                            id: doc.documentID,
                            alias: data["alias"] as? String,
                            name: data["name"] as? String,
                            email: data["email"] as? String,
                            photoUrl: data["photo_url"] as? String,
                            gender: data["gender"] as? String
                        )
                    }
                }
            }
            
            for try await part in group {
                results.append(contentsOf: part)
            }
        }
        
        // 保持原有顺序
        let order = Dictionary(uniqueKeysWithValues: userIds.enumerated().map { ($0.element, $0.offset) })
        results.sort { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
        
        return results
    }
    
    /// 初始化读取当前使用者的好友清单（建议在登入后调用一次）
    /// 此方法保留用于向后兼容，实际使用 getFriends 方法
    func loadFriends(for userId: String) async {
        _ = await getFriends(for: userId)
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
        db.collection("friends").addDocument(data: data) { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                guard let self = self else { return }
                self.friendIds.insert(targetUserId)
                // 刷新缓存
                Task {
                    _ = await self.refreshFriendsFromFirebase(for: currentUserId)
                }
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
        cacheManager.removeFriendFromCache(friendId: targetUserId, for: currentUserId)
        cachedFriends.removeAll { $0.id == targetUserId }
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
        // 刷新朋友名单缓存
        Task {
            _ = await self.refreshFriendsFromFirebase(for: receiverId)
        }
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
    
    /// 清除指定用户的缓存（登出时调用）
    func clearCache(for userId: String) {
        cacheManager.clearCache(for: userId)
        cachedFriends = []
        friendIds = []
    }
}

// MARK: - 数组分批扩展
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}
