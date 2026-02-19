//
//  MemberView.swift
//  Secalender
//
//  Created by linping on 2024/7/1.
//

import SwiftUI
import FirebaseFirestore

struct MemberView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showSignInView: Bool = false
    @State private var pendingRequestCount: Int = 0
    @State private var listener: ListenerRegistration?

    @State private var hasInitialized = false //修改内容：避免重复初始化
    
    // MARK: - Private Methods
    
    private func setupRequestCountListener() {
        //修改内容：如果已存在 listener，先移除再建（保留你的逻辑）
        listener?.remove()
        listener = nil
        
        guard !userManager.userOpenId.isEmpty else { return }
        
        let db = Firestore.firestore()
        let query = db.collection("friend_requests")
            .whereField("to", isEqualTo: userManager.userOpenId)
            .whereField("status", isEqualTo: "pending")
        
        print("🔍 设置请求数量监听器，用户ID: \(userManager.userOpenId)")
        
        listener = query.addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ 请求数量监听器错误: \(error.localizedDescription)")
                return
            }
            
            //修改内容：用 MainActor 统一处理 UI 状态
            Task { @MainActor in
                let count = snapshot?.documents.count ?? 0
                print("📊 待处理请求数量: \(count)")
                self.pendingRequestCount = count
            }
        }
    }
    
    private func refreshData() async {
        //修改内容：如果你选择用 listener，当 refresh 时只 refresh user 资料即可
        userManager.refresh()
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - 用户信息
                Section {
                    NavigationLink(destination: EditProfileView().environmentObject(userManager)) {
                        HStack {
                            if let photoUrl = userManager.photoUrl, let url = URL(string: photoUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                         .scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(userManager.displayName ?? "member.default_user".localized())
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                if let userCode = userManager.userCode {
                                    Text("member.user_id".localized() + ": \(userCode)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: - 好友功能
                Section(header: Text("member.friends".localized())) {
                    NavigationLink(destination: AddFriendView()) {
                        Label("member.add_friend".localized(), systemImage: "person.badge.plus")
                    }
                    NavigationLink(destination: MyFriendListView()) {
                        Label("member.friend_list".localized(), systemImage: "person.3.fill")
                    }
                    NavigationLink(destination: ReceivedFriendRequestsView()) {
                        HStack {
                            Label("member.received_requests".localized(), systemImage: "envelope")
                            Spacer()
                            if pendingRequestCount > 0 {
                                Text("\(pendingRequestCount)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // MARK: - 分享功能
                Section(header: Text("member.share".localized())) {
                    NavigationLink(destination: ShareHistoryView()) {
                        Label("member.share_history".localized(), systemImage: "square.and.arrow.up")
                    }
                    NavigationLink(destination: ShareNotificationsView()) {
                        Label("member.share_notifications".localized(), systemImage: "bell")
                    }
                    NavigationLink(destination: EventInvitationsView()) {
                        Label("member.event_invitations".localized(), systemImage: "calendar.badge.plus")
                    }
                }

                // MARK: - 任务成就
                Section(header: Text("member.achievements".localized())) {
                    NavigationLink(destination: AchievementsContentView()) {
                        Label("member.achievements_tasks".localized(), systemImage: "star.fill")
                    }
                }

                // MARK: - 设定
                Section(header: Text("member.settings".localized())) {
                    NavigationLink(destination: SettingsView(showSignInView: $showSignInView)) {
                        Label("settings.title".localized(), systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("member.title".localized())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }
            .refreshable {
                await refreshData()
            }
            .onAppear {
                //修改内容：避免每次出现都重复 refresh + 重建监听
                guard !hasInitialized else { return }
                hasInitialized = true
                
                userManager.refresh()
                setupRequestCountListener()
            }
            .onChange(of: userManager.userOpenId) { _ in
                //修改内容：如果用户切换（登出/登入），重新绑定监听
                setupRequestCountListener()
            }
            .onDisappear {
                listener?.remove()
                listener = nil
                hasInitialized = false //修改内容：如果你希望 Tab 切回来要重新建 listener，就保留；否则可删掉这行
            }
        }
    }
}

// MARK: - 成就内容视图（从AchievementsView整合）
struct AchievementsContentView: View {
    @State private var achievements: [Achievement] = [
        Achievement(title: "achievements.early_bird.title".localized(),
                    description: "achievements.early_bird.description".localized(),
                    progress: 0.5),
        Achievement(title: "achievements.family_trips.title".localized(),
                    description: "achievements.family_trips.description".localized(),
                    progress: 0.2),
        Achievement(title: "achievements.low_carbon.title".localized(),
                    description: "achievements.low_carbon.description".localized(),
                    progress: 0.7)
    ]

    var body: some View {
        List {
            ForEach(achievements) { achievement in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(achievement.title).font(.headline)
                        Spacer()
                        Text(String(format: "%.0f%%", achievement.progress * 100))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Text(achievement.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ProgressView(value: achievement.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("member.achievements_tasks".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MemberView_Previews: PreviewProvider {
    static var previews: some View {
        MemberView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
