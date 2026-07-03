//
//  Group.swift
//  Secalender
//
//  Created by 林平 on 2025/8/10.
//

import FirebaseFirestoreSwift
import Foundation

/// 關注權限類型
enum GroupPrivacy: String, Codable, CaseIterable {
    case `public` = "public"      // 自由（可被搜索可自由關注）
    case `private` = "private"    // 私人（無法被搜索到）
    case review = "review"        // 審核（可被搜索，關注需要群創建人審核）
    
    var displayName: String {
        switch self {
        case .public:
            return "自由"
        case .private:
            return "私人"
        case .review:
            return "審核"
        }
    }
    
    var description: String {
        switch self {
        case .public:
            return "可被搜索可自由關注"
        case .private:
            return "無法被搜索到"
        case .review:
            return "可被搜索，關注需要群創建人審核"
        }
    }
}

struct CommunityGroup: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var category: String?          // 社群分類
    var location: String?          // 地點（城市）
    var privacy: GroupPrivacy     // 關注權限
    var members: [String]           // 成員列表（openid）
    var owner: String               // 建立者
    var admins: [String]             // 管理員列表（openid），預設包含 owner
    var createdAt: Date?            // 建立時間

    init(id: String? = nil,
         name: String = "",
         description: String = "",
         category: String? = nil,
         location: String? = nil,
         privacy: GroupPrivacy = .public,
         members: [String] = [],
         owner: String = "",
         admins: [String] = [],
         createdAt: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.location = location
        self.privacy = privacy
        self.members = members
        self.owner = owner
        // 如果沒有指定 admins，預設 owner 為管理員
        self.admins = admins.isEmpty && !owner.isEmpty ? [owner] : admins
        self.createdAt = createdAt
    }
    
    /// 檢查用戶是否為管理員
    func isAdmin(userId: String) -> Bool {
        return owner == userId || admins.contains(userId)
    }
    
    /// 檢查用戶是否為擁有者
    func isOwner(userId: String) -> Bool {
        return owner == userId
    }
    
    /// 檢查用戶是否有管理權限（擁有者或管理員）
    func hasManagePermission(userId: String) -> Bool {
        return isOwner(userId: userId) || isAdmin(userId: userId)
    }
}
