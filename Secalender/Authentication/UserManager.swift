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
}

final class UserManager {
    static let shared = UserManager()
    private init() {}

    func createNewUser(auth: AuthDataResultModel) async throws {
        let docRef = Firestore.firestore().collection("users").document(auth.uid)
        let snapshot = try await docRef.getDocument()
        guard !snapshot.exists else { return }  // 不重复建立

        var userData: [String: Any] = [
            "user_id": auth.uid,
            "is_anonymous": auth.isAnonymous,
            "date_created": Timestamp(),
            "alias": "",
            "name": "",
            "gender": "",
            "phone": "",
            "role": "member"
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
            role: data["role"] as? String
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
}
