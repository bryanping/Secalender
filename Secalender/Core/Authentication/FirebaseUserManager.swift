//
//  FirebaseUserManager.swift
//  Secalender
//
//  Created by ChatGPT on 2025/6/4.
//

import Foundation
import FirebaseAuth
import SwiftUI

class FirebaseUserManager: ObservableObject {
    @Published var userOpenId: String = ""
    @Published var isSignedIn: Bool = false

    init() {
        listenToAuthChanges()
    }

    /// 监听登录状态变化并更新 userOpenId
    private func listenToAuthChanges() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                self.userOpenId = user.uid
                self.isSignedIn = true
            } else {
                self.userOpenId = ""
                self.isSignedIn = false
            }
        }
    }

    /// 手动刷新一次用户状态（可用于首次强制更新）
    func refresh() {
        if let user = Auth.auth().currentUser {
            self.userOpenId = user.uid
            self.isSignedIn = true
        } else {
            self.userOpenId = ""
            self.isSignedIn = false
        }
    }

    /// 登出用户
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userOpenId = ""
            self.isSignedIn = false
        } catch {
            print("登出失败：\(error.localizedDescription)")
        }
    }
}
