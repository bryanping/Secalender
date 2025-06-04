//
//  FriendSelectionView.swift
//  Secalender
//

import SwiftUI
import Firebase

struct FriendSelectionView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Binding var selectedFriends: [String]
    let onComplete: () -> Void
    
    @State private var friends: [FriendEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
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
                    Text("添加好友后才能分享活动")
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
            
            if let message = errorMessage {
                Text(message)
                    .foregroundColor(.red)
                    .padding()
            }
            
            HStack(spacing: 16) {
                Button("取消") {
                    selectedFriends = []
                    onComplete()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("确定") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFriends.isEmpty)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("选择好友")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFriends()
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
                    self.errorMessage = "加载失败: \(error.localizedDescription)"
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
                            self.errorMessage = "获取好友详情失败: \(err.localizedDescription)"
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
    }
}