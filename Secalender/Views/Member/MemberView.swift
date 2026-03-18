//
//  MemberView.swift
//  Secalender
//
//  Created by linping on 2024/7/1.
//  個人中心主頁：對齊創作者設計
//

import SwiftUI
import FirebaseFirestore

struct MemberView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showSignInView: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var pendingRequestCount: Int = 0
    @State private var listener: ListenerRegistration?
    @State private var hasInitialized = false

    private func setupRequestCountListener() {
        listener?.remove()
        listener = nil
        guard !userManager.userOpenId.isEmpty else { return }

        let db = Firestore.firestore()
        let query = db.collection("friend_requests")
            .whereField("to", isEqualTo: userManager.userOpenId)
            .whereField("status", isEqualTo: "pending")

        listener = query.addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ 请求数量监听器错误: \(error.localizedDescription)")
                return
            }
            Task { @MainActor in
                self.pendingRequestCount = snapshot?.documents.count ?? 0
            }
        }
    }

    private func refreshData() async {
        userManager.refresh()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 個人中心
                    ProfileHeaderView()
                        .environmentObject(userManager)

                    // 我的資產
                    MemberAssetsSection()
                        .environmentObject(userManager)

                    // 社群影響力
                    CommunityInfluenceSection()
                        .environmentObject(userManager)

                    // 商業中心
                    BusinessCenterSection()

                    // 內容批量管理（獨立卡片）
                    contentBatchCard

                    // 快捷入口
                    quickLinksSection
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: PersonalProfileView().environmentObject(userManager)) {
                        Text("profile_page.title".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        NavigationLink(destination: SettingsView(showSignInView: $showSignInView)) {
                            Image(systemName: "gearshape.fill")
                                .font(.body)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 80)
            }
            .refreshable {
                await refreshData()
            }
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true
                userManager.refresh()
                setupRequestCountListener()
            }
            .onChange(of: userManager.userOpenId) { _, _ in
                setupRequestCountListener()
            }
            .onDisappear {
                listener?.remove()
                listener = nil
                hasInitialized = false
            }
            .sheet(isPresented: $showShareSheet) {
                ShareProfileSheetView(userName: userManager.displayName ?? "", userCode: userManager.userCode ?? "")
            }
        }
    }

    private var contentBatchCard: some View {
        NavigationLink(destination: ContentBatchManagementView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "gearshape.2")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("member.assets_batch_manage".localized())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("member.assets_batch_hint".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("member.quick_links".localized())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                NavigationLink(destination: AddFriendView()) {
                    settingsRow(icon: "person.badge.plus", title: "member.add_friend".localized())
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 44)

                NavigationLink(destination: MyFriendListView()) {
                    settingsRow(icon: "person.3.fill", title: "member.friend_list".localized())
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 44)

                NavigationLink(destination: ReceivedFriendRequestsView()) {
                    HStack {
                        settingsRowContent(icon: "envelope", title: "member.received_requests".localized())
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
                .buttonStyle(.plain)

                Divider().padding(.leading, 44)

                NavigationLink(destination: ShareHistoryView()) {
                    settingsRow(icon: "square.and.arrow.up", title: "member.share_history".localized())
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 44)

                NavigationLink(destination: EventInvitationsView()) {
                    settingsRow(icon: "calendar.badge.plus", title: "member.event_invitations".localized())
                }
                .buttonStyle(.plain)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
    }

    private func settingsRow(icon: String, title: String) -> some View {
        HStack {
            settingsRowContent(icon: icon, title: title)
        }
        .padding(12)
    }

    private func settingsRowContent(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, alignment: .center)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 成就内容视图（从AchievementsView整合，使用 InfluenceDataManager 真實數據）
struct AchievementsContentView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @StateObject private var influenceManager = InfluenceDataManager.shared
    
    var body: some View {
        List {
            ForEach(influenceManager.achievementProgress(for: userManager.userOpenId)) { prog in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: prog.definition.icon)
                            .foregroundColor(prog.isUnlocked ? .blue : .gray)
                        Text(prog.definition.localizedKey.localized()).font(.headline)
                        Spacer()
                        if prog.isUnlocked {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Text(String(format: "%.0f%%", prog.progress * 100))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    Text("\(prog.current)/\(prog.definition.targetCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ProgressView(value: prog.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: prog.isUnlocked ? .green : .blue))
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("member.achievements_tasks".localized())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await influenceManager.load(for: userManager.userOpenId)
        }
    }
}

struct MemberView_Previews: PreviewProvider {
    static var previews: some View {
        MemberView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
