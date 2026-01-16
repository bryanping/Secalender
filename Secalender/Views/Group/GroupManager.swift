//
//  GroupManager.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

/// 社群管理器，處理社群相關的 CRUD 操作
final class GroupManager {
    static let shared = GroupManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    // MARK: - 搜索缓存和去重
    
    /// 搜索缓存：避免短时间内重复相同的查询
    private var searchCache: [String: (results: [CommunityGroup], timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 30 // 30秒缓存有效期
    
    /// 正在进行的搜索任务（去重）
    private var ongoingSearchTasks: [String: Task<[CommunityGroup], Error>] = [:]
    
    // MARK: - 社群管理
    
    /// 創建新社群
    func createGroup(
        name: String,
        description: String,
        category: String? = nil,
        location: String? = nil,
        privacy: GroupPrivacy = .public,
        ownerId: String,
        initialMembers: [String] = []
    ) async throws -> String {
        var members = initialMembers
        if !members.contains(ownerId) {
            members.append(ownerId)
        }
        
        let group = CommunityGroup(
            name: name,
            description: description,
            category: category,
            location: location,
            privacy: privacy,
            members: members,
            owner: ownerId,
            admins: [ownerId], // 擁有者自動成為管理員
            createdAt: Date()
        )
        
        let docRef = try db.collection("groups").addDocument(from: group)
        return docRef.documentID
    }
    
    /// 更新社群信息
    func updateGroup(
        groupId: String,
        name: String? = nil,
        description: String? = nil
    ) async throws {
        var updates: [String: Any] = [:]
        
        if let name = name {
            updates["name"] = name
        }
        if let description = description {
            updates["description"] = description
        }
        
        guard !updates.isEmpty else { return }
        
        try await db.collection("groups").document(groupId).updateData(updates)
    }
    
    /// 刪除社群（僅擁有者可刪除）
    func deleteGroup(groupId: String, userId: String) async throws {
        let group = try await getGroup(groupId: groupId)
        
        guard group.owner == userId else {
            throw GroupError.permissionDenied("只有擁有者可以刪除社群")
        }
        
        try await db.collection("groups").document(groupId).delete()
    }
    
    /// 獲取社群信息
    func getGroup(groupId: String) async throws -> CommunityGroup {
        let doc = try await db.collection("groups").document(groupId).getDocument()
        
        guard let group = try? doc.data(as: CommunityGroup.self) else {
            throw GroupError.groupNotFound
        }
        
        return group
    }
    
    /// 獲取用戶的所有社群
    func getUserGroups(userId: String) async throws -> [CommunityGroup] {
        let snapshot = try await db.collection("groups")
            .whereField("members", arrayContains: userId)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: CommunityGroup.self)
        }
    }
    
    // MARK: - 搜索功能
    
    /// 計算字符串相似度（使用最長公共子序列的簡化版本）
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = str1.lowercased()
        let s2 = str2.lowercased()
        
        // 如果完全匹配
        if s1 == s2 {
            return 1.0
        }
        
        // 如果一個包含另一個
        if s1.contains(s2) || s2.contains(s1) {
            let minLen = min(s1.count, s2.count)
            let maxLen = max(s1.count, s2.count)
            return Double(minLen) / Double(maxLen)
        }
        
        // 計算最長公共子序列長度
        let lcsLength = longestCommonSubsequence(s1, s2)
        let maxLen = max(s1.count, s2.count)
        
        return Double(lcsLength) / Double(maxLen)
    }
    
    /// 計算最長公共子序列長度
    private func longestCommonSubsequence(_ s1: String, _ s2: String) -> Int {
        let chars1 = Array(s1)
        let chars2 = Array(s2)
        let m = chars1.count
        let n = chars2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if chars1[i - 1] == chars2[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        
        return dp[m][n]
    }
    
    /// 搜索社群（按名稱相似度或ID，带缓存和去重）
    /// - Parameters:
    ///   - query: 搜索關鍵詞（可以是社群名稱或ID）
    ///   - minSimilarity: 最小相似度（默認0.5，即50%）
    /// - Returns: 符合條件的社群列表
    func searchGroups(query: String, minSimilarity: Double = 0.5) async throws -> [CommunityGroup] {
        guard !query.isEmpty else { return [] }
        
        // 创建缓存键（包含查询和相似度阈值）
        let cacheKey = "\(query.lowercased()):\(minSimilarity)"
        
        // 检查缓存
        if let cached = searchCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            return cached.results
        }
        
        // 检查是否有正在进行的相同搜索任务（去重）
        if let ongoingTask = ongoingSearchTasks[cacheKey] {
            // 等待正在进行的任务完成
            return try await ongoingTask.value
        }
        
        // 创建新的搜索任务
        let searchTask = Task<[CommunityGroup], Error> {
            defer {
                // 任务完成后移除
                Task { @MainActor in
                    self.ongoingSearchTasks.removeValue(forKey: cacheKey)
                }
            }
            
            var results: [CommunityGroup] = []
            
            // 首先嘗試按ID搜索（精確匹配）
            do {
                let doc = try await db.collection("groups").document(query).getDocument()
                if doc.exists, var group = try? doc.data(as: CommunityGroup.self) {
                    group.id = doc.documentID
                    // 确保只有可搜索的社群被返回
                    if group.privacy != .private {
                        results.append(group)
                    }
                }
            } catch {
                // ID搜索失敗，繼續按名稱搜索
            }
            
            // 按名稱搜索（獲取所有社群，然後在本地過濾）
            // 注意：Firestore 不支持模糊搜索，所以我們需要獲取所有社群
            // 在實際生產環境中，可以考慮使用 Algolia 或其他搜索服務
            let snapshot = try await db.collection("groups").getDocuments()
            
            let allGroups = snapshot.documents.compactMap { doc -> CommunityGroup? in
                guard var group = try? doc.data(as: CommunityGroup.self) else { return nil }
                group.id = doc.documentID
                return group
            }
            
            // 過濾：計算相似度，並且只搜索可被搜索的社群（自由和審核權限）
            let filteredGroups = allGroups.filter { group in
                // 如果已經在結果中（通過ID找到的），跳過
                if results.contains(where: { $0.id == group.id }) {
                    return false
                }
                
                // 只搜索可被搜索的社群（自由和審核權限），排除私人社群
                guard group.privacy != .private else {
                    return false
                }
                
                let similarity = calculateSimilarity(query, group.name)
                return similarity >= minSimilarity
            }
            
            results.append(contentsOf: filteredGroups)
            
            // 再次過濾結果，確保只返回可被搜索的社群
            let finalResults = results.filter { $0.privacy != .private }
            
            // 更新缓存
            Task { @MainActor in
                self.searchCache[cacheKey] = (results: finalResults, timestamp: Date())
                
                // 清理过期的缓存（保留最多50个条目）
                if self.searchCache.count > 50 {
                    let sortedCache = self.searchCache.sorted { $0.value.timestamp < $1.value.timestamp }
                    for (key, _) in sortedCache.prefix(self.searchCache.count - 50) {
                        self.searchCache.removeValue(forKey: key)
                    }
                }
            }
            
            return finalResults
        }
        
        // 保存正在进行的任务
        Task { @MainActor in
            self.ongoingSearchTasks[cacheKey] = searchTask
        }
        
        return try await searchTask.value
    }
    
    // MARK: - 成員管理
    
    /// 添加成員到社群
    func addMember(groupId: String, memberId: String, userId: String) async throws {
        let group = try await getGroup(groupId: groupId)
        
        guard group.hasManagePermission(userId: userId) else {
            throw GroupError.permissionDenied("只有管理員可以添加成員")
        }
        
        guard !group.members.contains(memberId) else {
            throw GroupError.memberAlreadyExists
        }
        
        try await db.collection("groups").document(groupId).updateData([
            "members": FieldValue.arrayUnion([memberId])
        ])
    }
    
    /// 用戶自己加入社群（公開加入）
    func joinGroupPublicly(groupId: String, userId: String) async throws {
        let group = try await getGroup(groupId: groupId)
        
        guard !group.members.contains(userId) else {
            throw GroupError.memberAlreadyExists
        }
        
        // 允許用戶自己加入社群（公開加入機制）
        try await db.collection("groups").document(groupId).updateData([
            "members": FieldValue.arrayUnion([userId])
        ])
    }
    
    /// 移除成員
    func removeMember(groupId: String, memberId: String, userId: String) async throws {
        let group = try await getGroup(groupId: groupId)
        
        guard group.hasManagePermission(userId: userId) else {
            throw GroupError.permissionDenied("只有管理員可以移除成員")
        }
        
        guard memberId != group.owner else {
            throw GroupError.cannotRemoveOwner
        }
        
        // 如果移除的是管理員，同時從管理員列表中移除
        var updates: [String: Any] = [
            "members": FieldValue.arrayRemove([memberId])
        ]
        
        if group.admins.contains(memberId) {
            updates["admins"] = FieldValue.arrayRemove([memberId])
        }
        
        try await db.collection("groups").document(groupId).updateData(updates)
    }
    
    /// 邀請成員（批量添加）
    func inviteMembers(groupId: String, memberIds: [String], userId: String) async throws {
        let group = try await getGroup(groupId: groupId)
        
        guard group.hasManagePermission(userId: userId) else {
            throw GroupError.permissionDenied("只有管理員可以邀請成員")
        }
        
        let newMembers = memberIds.filter { !group.members.contains($0) }
        
        guard !newMembers.isEmpty else {
            throw GroupError.allMembersAlreadyExist
        }
        
        try await db.collection("groups").document(groupId).updateData([
            "members": FieldValue.arrayUnion(newMembers)
        ])
    }
    
    /// 離開社群
    func leaveGroup(groupId: String, userId: String) async throws {
        let group = try await getGroup(groupId: groupId)
        
        guard group.owner != userId else {
            throw GroupError.ownerCannotLeave
        }
        
        var updates: [String: Any] = [
            "members": FieldValue.arrayRemove([userId])
        ]
        
        // 如果是管理員，同時從管理員列表中移除
        if group.admins.contains(userId) {
            updates["admins"] = FieldValue.arrayRemove([userId])
        }
        
        try await db.collection("groups").document(groupId).updateData(updates)
    }
    
    // MARK: - 權限管理
    
    /// 設置管理員
    func setAdmin(groupId: String, memberId: String, userId: String) async throws {
        let group = try await getGroup(groupId: groupId)
        
        guard group.isOwner(userId: userId) else {
            throw GroupError.permissionDenied("只有擁有者可以設置管理員")
        }
        
        guard group.members.contains(memberId) else {
            throw GroupError.memberNotFound
        }
        
        guard !group.admins.contains(memberId) else {
            throw GroupError.alreadyAdmin
        }
        
        try await db.collection("groups").document(groupId).updateData([
            "admins": FieldValue.arrayUnion([memberId])
        ])
    }
    
    /// 取消管理員權限
    func removeAdmin(groupId: String, memberId: String, userId: String) async throws {
        let group = try await getGroup(groupId: groupId)
        
        guard group.isOwner(userId: userId) else {
            throw GroupError.permissionDenied("只有擁有者可以取消管理員權限")
        }
        
        guard group.admins.contains(memberId) else {
            throw GroupError.notAdmin
        }
        
        guard memberId != group.owner else {
            throw GroupError.cannotRemoveOwnerAdmin
        }
        
        try await db.collection("groups").document(groupId).updateData([
            "admins": FieldValue.arrayRemove([memberId])
        ])
    }
    
    /// 獲取社群成員詳情
    func getGroupMembers(groupId: String) async throws -> [GroupMemberInfo] {
        let group = try await getGroup(groupId: groupId)
        
        guard !group.members.isEmpty else { return [] }
        
        // 嘗試使用 user_id 字段查詢
        let snapshot = try? await db.collection("users")
            .whereField("user_id", in: group.members)
            .getDocuments()
        
        var members: [GroupMemberInfo] = []
        
        if let snapshot = snapshot, !snapshot.documents.isEmpty {
            // 創建 user_id 到文檔的映射
            var userIdToDoc: [String: QueryDocumentSnapshot] = [:]
            for doc in snapshot.documents {
                if let userId = doc.data()["user_id"] as? String {
                    userIdToDoc[userId] = doc
                }
            }
            
            // 按照 group.members 的順序返回成員
            for memberId in group.members {
                if let doc = userIdToDoc[memberId] {
                    let data = doc.data()
                    members.append(GroupMemberInfo(
                        userId: memberId,
                        documentId: doc.documentID,
                        alias: data["alias"] as? String,
                        name: data["name"] as? String,
                        email: data["email"] as? String,
                        photoUrl: data["photo_url"] as? String,
                        gender: data["gender"] as? String
                    ))
                }
            }
        } else {
            // 如果 user_id 查詢失敗，嘗試使用 openid 字段
            let openidSnapshot = try await db.collection("users")
                .whereField("openid", in: group.members)
                .getDocuments()
            
            var openidToDoc: [String: QueryDocumentSnapshot] = [:]
            for doc in openidSnapshot.documents {
                if let openid = doc.data()["openid"] as? String {
                    openidToDoc[openid] = doc
                }
            }
            
            for memberId in group.members {
                if let doc = openidToDoc[memberId] {
                    let data = doc.data()
                    members.append(GroupMemberInfo(
                        userId: memberId,
                        documentId: doc.documentID,
                        alias: data["alias"] as? String,
                        name: data["name"] as? String ?? data["displayName"] as? String,
                        email: data["email"] as? String,
                        photoUrl: data["photo_url"] as? String ?? data["photoUrl"] as? String,
                        gender: data["gender"] as? String
                    ))
                }
            }
        }
        
        return members
    }
}

// MARK: - 社群成員信息
struct GroupMemberInfo: Identifiable {
    let userId: String  // 社群中的 user_id (openid)
    let documentId: String  // Firestore 文檔 ID
    let alias: String?
    let name: String?
    let email: String?
    let photoUrl: String?
    let gender: String?
    
    var id: String { userId }  // 使用 userId 作為 Identifiable 的 id
    
    /// 轉換為 FriendEntry（用於兼容現有代碼）
    func toFriendEntry() -> FriendEntry {
        FriendEntry(
            id: userId,  // 使用 userId 而不是 documentId
            alias: name,
            name: name,
            email: email,
            photoUrl: photoUrl,
            gender: gender
        )
    }
}

// MARK: - 錯誤定義
enum GroupError: LocalizedError {
    case groupNotFound
    case permissionDenied(String)
    case memberNotFound
    case memberAlreadyExists
    case allMembersAlreadyExist
    case cannotRemoveOwner
    case ownerCannotLeave
    case alreadyAdmin
    case notAdmin
    case cannotRemoveOwnerAdmin
    
    var errorDescription: String? {
        switch self {
        case .groupNotFound:
            return "社群不存在"
        case .permissionDenied(let message):
            return message
        case .memberNotFound:
            return "成員不存在"
        case .memberAlreadyExists:
            return "成員已在社群中"
        case .allMembersAlreadyExist:
            return "所有成員已在社群中"
        case .cannotRemoveOwner:
            return "無法移除擁有者"
        case .ownerCannotLeave:
            return "擁有者無法離開社群，請先轉移擁有權或刪除社群"
        case .alreadyAdmin:
            return "該成員已是管理員"
        case .notAdmin:
            return "該成員不是管理員"
        case .cannotRemoveOwnerAdmin:
            return "無法移除擁有者的管理員權限"
        }
    }
}
