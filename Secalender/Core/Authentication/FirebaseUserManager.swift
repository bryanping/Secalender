//
//  FirebaseUserManager.swift
//  Secalender
//
//  Created by 林平 on 2025/5/30.
//

import Foundation
import FirebaseAuth
import Combine

class FirebaseUserManager: ObservableObject {
    static let shared = FirebaseUserManager()
    private init() {
        self.user = Auth.auth().currentUser
        self.listenForChanges()
    }

    @Published var user: User?

    var userOpenId: String {
        user?.uid ?? "unknown_user"
    }

    var userEmail: String {
        user?.email ?? "unknown@email.com"
    }

    private func listenForChanges() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.user = user
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        self.user = nil
    }
}
