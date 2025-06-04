//
//  GroupManager.swift
//  Secalender
//
//  Created by 林平 on 2025/6/7.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class GroupManager {
    static let shared = GroupManager()
    private let db = Firestore.firestore()

    private init() {}

    func createGroup(name: String, memberIds: [String], createdBy: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let group = Group(name: name, createdBy: createdBy, memberIds: memberIds, createdAt: Date())
        do {
            _ = try db.collection("groups").addDocument(from: group) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func fetchGroups(forUserId userId: String, completion: @escaping (Result<[Group], Error>) -> Void) {
        db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    let groups = snapshot?.documents.compactMap { doc -> Group? in
                        try? doc.data(as: Group.self)
                    } ?? []
                    completion(.success(groups))
                }
            }
    }
}
