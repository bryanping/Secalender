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
}

final class UserManager {
    
    static let shared = UserManager()
    private init() {}

    /// 建立新使用者資料（初次登入後呼叫）
    func createNewUser(auth: AuthDataResultModel) async throws {
        var userData: [String: Any] = [
            "user_id": auth.uid,
            "is_anonymous": auth.isAnonymous,
            "date_created": Timestamp(),
            "alias": "",     // 用户可自定义
            "name": "",
            "gender": "",
            "phone": ""
        ]
        
        if let email = auth.email {
            userData["email"] = email
        }
        if let photoUrl = auth.photoUrl {
            userData["photo_url"] = photoUrl
        }
        
        try await Firestore.firestore()
            .collection("users")
            .document(auth.uid)
            .setData(userData, merge: false)
    }

    /// 讀取單一使用者資料
    func getUser(userId: String) async throws -> DBUser {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .document(userId)
            .getDocument()
        
        guard let data = snapshot.data(),
              let userId = data["user_id"] as? String else {
            throw URLError(.badServerResponse)
        }
        
        let isAnonymous = data["is_anonymous"] as? Bool
        let email = data["email"] as? String
        let photoUrl = data["photo_url"] as? String
        let dateCreated = (data["date_created"] as? Timestamp)?.dateValue()
        
        let alias = data["alias"] as? String
        let name = data["name"] as? String
        let gender = data["gender"] as? String ?? "Unknown"
        let phone = data["phone"] as? String

        return DBUser(
            userId: userId,
            isAnonymous: isAnonymous,
            email: email,
            photoUrl: photoUrl,
            dateCreated: dateCreated,
            alias: alias,
            name: name,
            gender: gender,
            phone: phone
        )
    }

    /// 檢查別名是否唯一
    func isAliasUnique(alias: String) async throws -> Bool {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .whereField("alias", isEqualTo: alias)
            .getDocuments()
        
        return snapshot.documents.isEmpty
    }

    /// 更新別名（不可重複）
    func updateAlias(for userId: String, to alias: String) async throws {
        let isUnique = try await isAliasUnique(alias: alias)
        guard isUnique else {
            throw NSError(domain: "AliasAlreadyExists", code: 400, userInfo: [NSLocalizedDescriptionKey: "此別名已被使用"])
        }

        try await Firestore.firestore()
            .collection("users")
            .document(userId)
            .updateData(["alias": alias])
    }

    /// 搜尋使用者ID（透過 alias）
    func getUserIdByAlias(alias: String) async throws -> String? {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .whereField("alias", isEqualTo: alias)
            .getDocuments()
        
        return snapshot.documents.first?.documentID
    }
}
