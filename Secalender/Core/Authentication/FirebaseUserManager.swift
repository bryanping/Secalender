//
//  FirebaseUserManager.swift
//  Secalender
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class FirebaseUserManager: ObservableObject {
    static let shared = FirebaseUserManager()

    @Published var userOpenId: String = ""
    @Published var displayName: String?
    @Published var alias: String?
    @Published var gender: String?
    @Published var photoUrl: String?
    @Published var userRole: String = "member"
    @Published var friends: [String] = []

    private init() {
        listenToAuthChanges()
    }

    private func listenToAuthChanges() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self, let user = user else { return }
            self.userOpenId = user.uid
            self.loadUserData(userId: user.uid)
        }
    }

    func refresh() {
        if !userOpenId.isEmpty {
            loadUserData(userId: userOpenId)
        }
    }

    func ensureUserIsSignedIn(completion: @escaping (Bool) -> Void) {
        if let user = Auth.auth().currentUser {
            completion(true)
        } else {
            Auth.auth().signInAnonymously { result, error in
                completion(result != nil && error == nil)
            }
        }
    }

    private func loadUserData(userId: String) {
        Task {
            do {
                let dbUser = try await UserManager.shared.getUser(userId: userId)
                DispatchQueue.main.async {
                    self.alias = dbUser.alias
                    self.displayName = dbUser.name
                    self.gender = dbUser.gender
                    self.photoUrl = dbUser.photoUrl
                    self.userRole = dbUser.role ?? "member"
                }
                try await loadFriendIds(for: userId)
            } catch {
                print("读取用户资料失败：\(error.localizedDescription)")
            }
        }
    }

    private func loadFriendIds(for userId: String) async throws {
        // 从friends集合中获取当前用户的好友列表
        let snapshot = try await Firestore.firestore().collection("friends")
            .whereField("owner", isEqualTo: userId)
            .getDocuments()
        
        // 提取好友ID
        let ids = snapshot.documents.compactMap { $0["friend"] as? String }
        
        DispatchQueue.main.async { self.friends = ids }
    }
}
