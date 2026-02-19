//
//  ReceivedFriendRequestsView.swift
//  Secalender
//
//  Created by linping on 2025/6/5.
//

import SwiftUI
import Firebase
import FirebaseFirestore

// MARK: - 好友请求数据模型
struct FriendRequest: Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let message: String?
    let createdAt: Date?
    let senderInfo: DBUser?
}

struct ReceivedFriendRequestsView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var requests: [FriendRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var processingRequestId: String?
    @State private var listener: ListenerRegistration?

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("common.loading".localized())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if requests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("friend_requests.no_requests".localized())
                            .foregroundColor(.gray)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(requests) { request in
                            FriendRequestRow(
                                request: request,
                                onAccept: {
                                    Task {
                                        await acceptRequest(request)
                                    }
                                },
                                onReject: {
                                    Task {
                                        await rejectRequest(request)
                                    }
                                },
                                isProcessing: processingRequestId == request.id
                            )
                        }
                    }
                }

                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("friends.requests".localized())
            .refreshable {
                await loadRequests()
            }
            .onAppear {
                setupListener()
            }
            .onDisappear {
                listener?.remove()
                listener = nil
            }
        }
    }
    
    /// 设置实时监听器
    private func setupListener() {
        // 先移除旧的监听器
        listener?.remove()
        listener = nil
        
        guard !userManager.userOpenId.isEmpty else {
            print("⚠️ 用户ID为空，无法设置监听器")
            return
        }
        
        let db = Firestore.firestore()
        // 先查询，然后在客户端排序（避免需要 Firestore 复合索引）
        let query = db.collection("friend_requests")
            .whereField("to", isEqualTo: userManager.userOpenId)
            .whereField("status", isEqualTo: "pending")
        
        print("🔍 设置好友请求监听器，用户ID: \(userManager.userOpenId)")
        
        listener = query.addSnapshotListener { snapshot, error in
            Task {
                if let error = error {
                    print("❌ 好友请求监听器错误: \(error.localizedDescription)")
                    await MainActor.run {
                        self.errorMessage = "common.load_failed".localized() + ": \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("ℹ️ 没有找到好友请求文档")
                    await MainActor.run {
                        self.requests = []
                        self.isLoading = false
                    }
                    return
                }
                
                print("✅ 收到 \(documents.count) 个好友请求")
                
                // 获取发送者的用户信息
                var loadedRequests: [FriendRequest] = []
                
                for doc in documents {
                    let data = doc.data()
                    let fromUserId = data["from"] as? String ?? ""
                    
                    // 获取发送者信息
                    var senderInfo: DBUser? = nil
                    if !fromUserId.isEmpty {
                        do {
                            senderInfo = try await UserManager.shared.getUser(userId: fromUserId)
                        } catch {
                            print("获取用户信息失败: \(error.localizedDescription)")
                        }
                    }
                    
                    let request = FriendRequest(
                        id: doc.documentID,
                        fromUserId: fromUserId,
                        toUserId: data["to"] as? String ?? "",
                        message: data["message"] as? String,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                        senderInfo: senderInfo
                    )
                    loadedRequests.append(request)
                }
                
                // 在客户端按创建时间排序（降序）
                loadedRequests.sort { request1, request2 in
                    let date1 = request1.createdAt ?? Date.distantPast
                    let date2 = request2.createdAt ?? Date.distantPast
                    return date1 > date2
                }
                
                await MainActor.run {
                    self.requests = loadedRequests
                    self.isLoading = false
                }
            }
        }
    }

    private func loadRequests() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let requestDocs = try await FriendManager.shared.getReceivedFriendRequests(for: userManager.userOpenId)
            
            // 获取发送者的用户信息
            var loadedRequests: [FriendRequest] = []
            
            for doc in requestDocs {
                let data = doc.data()
                let fromUserId = data["from"] as? String ?? ""
                
                // 获取发送者信息
                var senderInfo: DBUser? = nil
                if !fromUserId.isEmpty {
                    do {
                        senderInfo = try await UserManager.shared.getUser(userId: fromUserId)
                    } catch {
                        print("获取用户信息失败: \(error.localizedDescription)")
                    }
                }
                
                let request = FriendRequest(
                    id: doc.documentID,
                    fromUserId: fromUserId,
                    toUserId: data["to"] as? String ?? "",
                    message: data["message"] as? String,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                    senderInfo: senderInfo
                )
                loadedRequests.append(request)
            }
            
            await MainActor.run {
                self.requests = loadedRequests
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载失败：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func acceptRequest(_ request: FriendRequest) async {
        processingRequestId = request.id
        
        do {
            try await FriendManager.shared.acceptFriendRequest(
                requestId: request.id,
                from: request.fromUserId,
                to: request.toUserId
            )
            
            // 从列表中移除
            await MainActor.run {
                self.requests.removeAll { $0.id == request.id }
                self.processingRequestId = nil
            }
            
            // 刷新好友列表
            await FriendManager.shared.loadFriends(for: userManager.userOpenId)
            userManager.refresh()
        } catch {
            await MainActor.run {
                self.errorMessage = "friend_requests.accept_failed".localized() + ": \(error.localizedDescription)"
                self.processingRequestId = nil
            }
        }
    }
    
    private func rejectRequest(_ request: FriendRequest) async {
        processingRequestId = request.id
        
        do {
            try await FriendManager.shared.rejectFriendRequest(requestId: request.id)
            
            // 从列表中移除
            await MainActor.run {
                self.requests.removeAll { $0.id == request.id }
                self.processingRequestId = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "friend_requests.reject_failed".localized() + ": \(error.localizedDescription)"
                self.processingRequestId = nil
            }
        }
    }
}

// MARK: - 好友请求行视图
struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onReject: () -> Void
    let isProcessing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            if let photoUrl = request.senderInfo?.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                Text(request.senderInfo?.name ?? request.senderInfo?.alias ?? request.senderInfo?.userCode ?? "friend_requests.unknown_user".localized())
                    .font(.headline)
                
                if let alias = request.senderInfo?.alias, !alias.isEmpty, alias != request.senderInfo?.name {
                    Text("friend_requests.alias".localized(with: alias))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let userCode = request.senderInfo?.userCode {
                    Text("ID: \(userCode)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }
                
                if let message = request.message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                Button("friend_requests.reject".localized()) {
                    onReject()
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
                
                Button("friend_requests.accept".localized()) {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 4)
        .opacity(isProcessing ? 0.6 : 1.0)
    }
}
