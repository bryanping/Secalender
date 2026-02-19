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
    @Published var userCode: String?  // 8位数字+大写字母ID
    @Published var region: String?    // 地区
    @Published var phone: String?     // 手机号
    @Published var userCodeModified: Bool = false  // ID是否已修改过
    @Published var favoriteTags: [String] = []  // 喜好标签
    @Published var signature: String?  // 个性签名

    // 修改内容：添加防抖和防重复机制
    private var isLoading = false
    private var lastRefreshTime: Date?
    private let minRefreshInterval: TimeInterval = 2.0 // 最小刷新间隔 2 秒
    private var refreshTask: Task<Void, Never>?

    private init() {
        listenToAuthChanges()
    }

    private func listenToAuthChanges() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self, let user = user else { return }
            // 修改内容：只在 userOpenId 改变时才加载，避免重复加载
            let userId = user.uid
            if self.userOpenId != userId {
                self.userOpenId = userId
                self.loadUserData(userId: userId)
            }
        }
    }

    func refresh() {
        // 修改内容：添加防抖和防重复机制
        guard !userOpenId.isEmpty else { return }
        
        // 取消之前的刷新任务
        refreshTask?.cancel()
        
        // 检查是否在最小刷新间隔内
        if let lastTime = lastRefreshTime,
           Date().timeIntervalSince(lastTime) < minRefreshInterval {
            return
        }
        
        // 如果正在加载，不重复加载
        guard !isLoading else { return }
        
        lastRefreshTime = Date()
        loadUserData(userId: userOpenId)
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
        // 修改内容：防止并发加载
        guard !isLoading else { return }
        
        isLoading = true
        refreshTask = Task { @MainActor in
            defer { self.isLoading = false }
            
            do {
                let dbUser = try await UserManager.shared.getUser(userId: userId)
                // 修改内容：检查任务是否被取消
                guard !Task.isCancelled else { return }
                
                self.alias = dbUser.alias
                // 優先使用 displayName，如果沒有則使用 name
                self.displayName = dbUser.displayName ?? dbUser.name
                self.gender = dbUser.gender
                self.photoUrl = dbUser.photoUrl
                self.userRole = dbUser.role ?? "member"
                self.userCode = dbUser.userCode
                self.region = dbUser.region
                self.phone = dbUser.phone
                self.userCodeModified = dbUser.userCodeModified ?? false
                self.favoriteTags = dbUser.favoriteTags ?? []
                self.signature = dbUser.signature
                
                try await loadFriendIds(for: userId)
            } catch {
                if !Task.isCancelled {
                    print("读取用户资料失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func loadFriendIds(for userId: String) async throws {
        // 修改内容：检查任务是否被取消
        guard !Task.isCancelled else { return }
        
        // 从friends集合中获取当前用户的好友列表
        let snapshot = try await Firestore.firestore().collection("friends")
            .whereField("owner", isEqualTo: userId)
            .getDocuments()
        
        // 提取好友ID
        let ids = snapshot.documents.compactMap { $0["friend"] as? String }
        
        // 修改内容：只在任务未被取消时更新UI
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.friends = ids
        }
    }
}
