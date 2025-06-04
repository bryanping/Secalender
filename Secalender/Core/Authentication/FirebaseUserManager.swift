//
//  FirebaseUserManager.swift
//  Secalender
//
//  Created by ChatGPT on 2025/6/4.
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

    private init() {
        listenToAuthChanges()
    }

    private func listenToAuthChanges() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                self.userOpenId = user.uid
                self.fetchUserData(userId: user.uid)
            }
        }
    }

    func refresh() {
        if !userOpenId.isEmpty {
            fetchUserData(userId: userOpenId)
        }
    }

    private func fetchUserData(userId: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            guard let data = snapshot?.data(), error == nil else { return }

            DispatchQueue.main.async {
                self.alias = data["alias"] as? String
                self.displayName = data["display_name"] as? String
                self.gender = data["gender"] as? String
                self.photoUrl = data["photo_url"] as? String
            }
        }
    }
}
