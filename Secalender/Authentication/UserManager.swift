//
//  UserManager.swift
//  Secalender
//
//  Created by linping on 2025/6/5.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct DBUser {
    let userId: String
    let isAnonymous: Bool?
    let email: String?
    let photoUrl: String?
    let dateCreated: Date?
    let alias: String?
    let name: String?
    let gender: String?
    let phone: String?
    let role: String?
    let userCode: String?  // 8位数字+大写字母ID
    let region: String?    // 地区
    let userCodeModified: Bool?  // ID是否已修改过（只能修改一次）
    let favoriteTags: [String]?  // 喜好标签（0-6个）
}

final class UserManager {
    static let shared = UserManager()
    private init() {}
    
    /// 生成8位数字+大写字母的唯一ID
    private func generateUserCode() -> String {
        let characters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        var code = ""
        for _ in 0..<8 {
            if let randomChar = characters.randomElement() {
                code.append(randomChar)
            }
        }
        return code
    }
    
    /// 生成唯一的用户ID（确保不重复）
    private func generateUniqueUserCode() async throws -> String {
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            let code = generateUserCode()
            let isUnique = try await isUserCodeUnique(userCode: code)
            if isUnique {
                return code
            }
            attempts += 1
        }
        
        throw NSError(domain: "UserCodeGenerationFailed", code: 500, userInfo: [NSLocalizedDescriptionKey: "无法生成唯一的用户ID，请稍后重试"])
    }

    func createNewUser(auth: AuthDataResultModel) async throws {
        let docRef = Firestore.firestore().collection("users").document(auth.uid)
        let snapshot = try await docRef.getDocument()
        guard !snapshot.exists else { return }  // 不重复建立

        // 生成唯一的8位ID
        let userCode = try await generateUniqueUserCode()

        var userData: [String: Any] = [
            "user_id": auth.uid,
            "is_anonymous": auth.isAnonymous,
            "date_created": Timestamp(),
            "alias": "",
            "name": "",
            "gender": "",
            "phone": "",
            "region": "",
            "role": "member",
            "user_code": userCode,
            "user_code_modified": false,  // 初始状态：未修改过
            "favorite_tags": []  // 初始状态：无喜好标签
        ]

        if let email = auth.email { userData["email"] = email }
        if let photoUrl = auth.photoUrl { userData["photo_url"] = photoUrl }

        try await docRef.setData(userData, merge: false)
    }

    func getUser(userId: String) async throws -> DBUser {
        let snapshot = try await Firestore.firestore().collection("users").document(userId).getDocument()
        guard let data = snapshot.data(), let userId = data["user_id"] as? String else {
            throw URLError(.badServerResponse)
        }

        return DBUser(
            userId: userId,
            isAnonymous: data["is_anonymous"] as? Bool,
            email: data["email"] as? String,
            photoUrl: data["photo_url"] as? String,
            dateCreated: (data["date_created"] as? Timestamp)?.dateValue(),
            alias: data["alias"] as? String,
            name: data["name"] as? String,
            gender: data["gender"] as? String,
            phone: data["phone"] as? String,
            role: data["role"] as? String,
            userCode: data["user_code"] as? String,
            region: data["region"] as? String,
            userCodeModified: data["user_code_modified"] as? Bool,
            favoriteTags: data["favorite_tags"] as? [String]
        )
    }

    func updateAlias(for userId: String, to alias: String) async throws {
        let isUnique = try await isAliasUnique(alias: alias)
        guard isUnique else {
            throw NSError(domain: "AliasAlreadyExists", code: 400, userInfo: [NSLocalizedDescriptionKey: "此别名已被使用"])
        }
        try await Firestore.firestore().collection("users").document(userId).updateData(["alias": alias])
    }

    func isAliasUnique(alias: String) async throws -> Bool {
        let snapshot = try await Firestore.firestore().collection("users").whereField("alias", isEqualTo: alias).getDocuments()
        return snapshot.documents.isEmpty
    }
    
    /// 检查用户ID是否唯一
    func isUserCodeUnique(userCode: String) async throws -> Bool {
        let snapshot = try await Firestore.firestore().collection("users").whereField("user_code", isEqualTo: userCode).getDocuments()
        return snapshot.documents.isEmpty
    }
    
    /// 更新用户ID（只能修改一次）
    func updateUserCode(for userId: String, to userCode: String) async throws {
        // 先检查用户是否已经修改过ID
        let user = try await getUser(userId: userId)
        if user.userCodeModified == true {
            throw NSError(domain: "UserCodeAlreadyModified", code: 400, userInfo: [NSLocalizedDescriptionKey: "用户ID只能修改一次"])
        }
        
        // 检查新ID是否唯一
        let isUnique = try await isUserCodeUnique(userCode: userCode)
        guard isUnique else {
            throw NSError(domain: "UserCodeAlreadyExists", code: 400, userInfo: [NSLocalizedDescriptionKey: "此ID已被使用"])
        }
        
        // 验证ID格式：8位数字+大写字母
        guard userCode.count == 8, userCode.allSatisfy({ $0.isNumber || ($0.isLetter && $0.isUppercase) }) else {
            throw NSError(domain: "InvalidUserCodeFormat", code: 400, userInfo: [NSLocalizedDescriptionKey: "ID必须是8位数字或大写字母"])
        }
        
        // 更新ID并标记为已修改
        try await Firestore.firestore().collection("users").document(userId).updateData([
            "user_code": userCode,
            "user_code_modified": true
        ])
    }
    
    /// 更新用户地区
    func updateRegion(for userId: String, to region: String) async throws {
        try await Firestore.firestore().collection("users").document(userId).updateData(["region": region])
    }
    
    /// 更新用户手机号
    func updatePhone(for userId: String, to phone: String) async throws {
        try await Firestore.firestore().collection("users").document(userId).updateData(["phone": phone])
    }
    
    /// 更新用户性别
    func updateGender(for userId: String, to gender: String) async throws {
        try await Firestore.firestore().collection("users").document(userId).updateData(["gender": gender])
    }
    
    /// 根据用户ID查找用户
    func getUserByCode(userCode: String) async throws -> DBUser? {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .whereField("user_code", isEqualTo: userCode)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first,
              let userId = document.data()["user_id"] as? String else {
            return nil
        }
        
        return try await getUser(userId: userId)
    }
    
    /// 更新用户喜好标签（0-6个）
    func updateFavoriteTags(for userId: String, to tags: [String]) async throws {
        // 验证标签数量（0-6个）
        guard tags.count <= 6 else {
            throw NSError(domain: "InvalidFavoriteTagsCount", code: 400, userInfo: [NSLocalizedDescriptionKey: "最多只能选择6个喜好标签"])
        }
        
        try await Firestore.firestore().collection("users").document(userId).updateData([
            "favorite_tags": tags
        ])
    }
    
    /// 获取所有可用的喜好标签选项
    static func getAvailableFavoriteTags() -> [String] {
        return [
            "旅行", "美食", "运动", "音乐", "电影",
            "阅读", "摄影", "绘画", "游戏", "购物",
            "咖啡", "茶艺", "宠物", "园艺", "手工",
            "舞蹈", "瑜伽", "健身", "跑步", "骑行",
            "游泳", "登山", "露营", "钓鱼", "烹饪",
            "烘焙", "收藏", "科技", "时尚", "艺术"
        ]
    }
}
