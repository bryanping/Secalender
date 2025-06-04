//
//  InviteFriendsView.swift
//  Secalender
//

import SwiftUI
import Firebase
import FirebaseFirestore

// 导入必要的模型和管理器

// 使用MyFriendListView中定义的FriendEntry结构体

struct InviteFriendsView: View {
    let event: Event
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedFriends: [String] = []
    @State private var friends: [FriendEntry] = []
    @State private var isLoading = true
    @State private var isInviting = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 活动信息预览
                VStack(alignment: .leading, spacing: 12) {
                    Text("邀请好友参加")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "calendar")
                            Text(event.date)
                        }
                        .foregroundColor(.gray)
                        
                        HStack {
                            Image(systemName: "clock")
                            Text("\(event.startTime) - \(event.endTime)")
                        }
                        .foregroundColor(.gray)
                        
                        if !event.destination.isEmpty {
                            HStack {
                                Image(systemName: "location")
                                Text(event.destination)
                            }
                            .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
                
                Divider()
                
                // 好友列表
                if isLoading {
                    ProgressView("加载好友列表...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无好友")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("添加好友后才能邀请参加活动")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(friends, id: \.id) { friend in
                            FriendSelectionRow(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id),
                                onToggle: {
                                    if selectedFriends.contains(friend.id) {
                                        selectedFriends.removeAll { $0 == friend.id }
                                    } else {
                                        selectedFriends.append(friend.id)
                                    }
                                }
                            )
                        }
                    }
                }
                
                // 底部操作区域
                VStack(spacing: 12) {
                    if let message = errorMessage {
                        Text(message)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    if showSuccessMessage {
                        Text("邀请发送成功！")
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 16) {
                        Button("取消") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("发送邀请") {
                            Task {
                                await sendInvitations()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedFriends.isEmpty || isInviting)
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                }
            }
            .navigationTitle("邀请好友")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadFriends()
            }
        }
    }
    
    private func loadFriends() {
        guard !userManager.userOpenId.isEmpty else { return }
        
        isLoading = true
        let db = Firestore.firestore()
        
        // 获取当前用户的好友列表
        db.collection("friends")
            .whereField("owner", isEqualTo: userManager.userOpenId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("加载好友列表失败: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }
                
                guard let docs = snapshot?.documents, !docs.isEmpty else {
                    self.isLoading = false
                    return
                }
                
                // 提取好友ID列表
                let friendIds = docs.compactMap { $0["friend"] as? String }
                
                // 如果没有好友，直接返回
                if friendIds.isEmpty {
                    self.isLoading = false
                    return
                }
                
                // 根据好友ID获取好友详细信息
                db.collection("users")
                    .whereField("openid", in: friendIds) // 使用openid字段匹配
                    .getDocuments { snap, err in
                        defer { self.isLoading = false }
                        
                        if let err = err {
                            print("获取好友详情失败: \(err.localizedDescription)")
                            return
                        }
                        
                        guard let documents = snap?.documents else { return }
                        
                        self.friends = documents.compactMap { doc in
                            let data = doc.data()
                            return FriendEntry(
                                id: doc.documentID,
                                alias: data["alias"] as? String,
                                name: data["displayName"] as? String, // 使用displayName字段
                                email: data["email"] as? String,
                                photoUrl: data["photoUrl"] as? String, // 使用photoUrl字段
                                gender: data["gender"] as? String
                            )
                        }
                    }
            }
    }
    
    private func sendInvitations() async {
        guard !selectedFriends.isEmpty else { return }
        
        isInviting = true
        errorMessage = nil
        
        do {
            try await EventManager.shared.inviteFriendsToEvent(
                eventId: event.id ?? 0,
                friendIds: selectedFriends,
                senderId: userManager.userOpenId
            )
            
            await MainActor.run {
                showSuccessMessage = true
                isInviting = false
                
                // 2秒后关闭页面
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "邀请失败：\(error.localizedDescription)"
                isInviting = false
            }
        }
    }
}

// 好友选择行组件
struct FriendSelectionRow: View {
    let friend: FriendEntry
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 头像
                if let urlStr = friend.photoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                             .scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                }
                
                // 好友信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.alias ?? friend.email ?? friend.name ?? "未知好友")
                        .font(.headline)
                    if let email = friend.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // 选择状态
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
        }
        .foregroundColor(.primary)
    }
}