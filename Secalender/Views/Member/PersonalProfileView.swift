//
//  PersonalProfileView.swift
//  Secalender
//
//  個人資料頁：對齊設計稿（頭像+驗證徽章、名稱、@句柄+複製、粉絲按鈕、主操作、統計、行程/主題/模板分頁）
//

import SwiftUI

struct PersonalProfileView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showShareSheet = false
    @State private var showEditProfile = false
    @State private var copiedId = false
    @State private var profileStats: UserProfileStats = .empty
    @State private var isLoadingStats = true
    @State private var myTrips: [Event] = []
    @State private var isLoadingTrips = false
    
    enum ProfileTab: String, CaseIterable {
        case trips
        case themes
        case templates
        var titleKey: String {
            switch self {
            case .trips: return "friend_detail.tab_trips"
            case .themes: return "friend_detail.tab_themes"
            case .templates: return "friend_detail.tab_templates"
            }
        }
    }
    @State private var selectedTab: ProfileTab = .trips
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 頭像 + 驗證徽章
                avatarSection
                
                // 名稱
                Text(userManager.displayName ?? "member.default_user".localized())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // @句柄 + 複製
                HStack(spacing: 6) {
                    Text("@\(userManager.userCode ?? "")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button(action: copyUserId) {
                        Image(systemName: copiedId ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                // 兩個「粉絲」按鈕（追蹤中 / 粉絲）
                HStack(spacing: 12) {
                    Button { } label: {
                        Text("profile_page.following".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    Button { } label: {
                        Text("member.followers".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                // 主操作：編輯資料（自己看自己）
                Button {
                    showEditProfile = true
                } label: {
                    Text("profile.edit_profile".localized())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                // 右側兩小按鈕：日曆、信封
                HStack(spacing: 12) {
                    Button { } label: {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Button { } label: {
                        Image(systemName: "envelope")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                // 統計：追蹤中、收藏、Saves、Likes（全部接後端）
                HStack(spacing: 0) {
                    profileStat(value: profileStats.followingCount, labelKey: "profile_page.following".localized())
                    statDivider
                    profileStat(value: profileStats.favoritesCount, labelKey: "member.favorites".localized())
                    statDivider
                    profileStat(value: profileStats.savesCount, labelKey: "profile_page.saves".localized())
                    statDivider
                    profileStat(value: profileStats.likesCount, labelKey: "member.likes".localized())
                }
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // 分頁：行程 / 主題 / 模板
                VStack(alignment: .leading, spacing: 12) {
                    Picker("", selection: $selectedTab) {
                        ForEach(ProfileTab.allCases, id: \.self) { tab in
                            Text(tab.titleKey.localized()).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    switch selectedTab {
                    case .trips:
                        profileTripsContent
                    case .themes:
                        profileThemesPlaceholder
                    case .templates:
                        profileTemplatesPlaceholder
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("profile_page.title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showShareSheet = true }) {
                        Label("member.share_profile".localized(), systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareProfileSheetView(userName: userManager.displayName ?? "", userCode: userManager.userCode ?? "")
        }
        .task {
            guard !userManager.userOpenId.isEmpty else { return }
            isLoadingStats = true
            profileStats = await UserProfileStatsService.shared.fetchStats(for: userManager.userOpenId)
            isLoadingStats = false
        }
        .refreshable {
            guard !userManager.userOpenId.isEmpty else { return }
            profileStats = await UserProfileStatsService.shared.fetchStats(for: userManager.userOpenId)
        }
        .sheet(isPresented: $showEditProfile) {
            NavigationView {
                EditProfileView()
                    .environmentObject(userManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("common.done".localized()) { showEditProfile = false }
                        }
                    }
            }
        }
    }
    
    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
            LocalUserAvatarView(
                userId: userManager.userOpenId,
                remotePhotoUrl: userManager.photoUrl,
                placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text((userManager.displayName ?? "?").prefix(1))
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                }
            )
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            if profileStats.isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color.blue))
                    .offset(x: 2, y: 2)
            }
        }
        .padding(.top, 8)
    }
    
    private var statDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 1, height: 28)
    }
    
    private func profileStat(value: Int, labelKey: String) -> some View {
        VStack(spacing: 4) {
            Text(formatCount(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(labelKey)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatCount(_ n: Int) -> String {
        if n >= 10000 { return String(format: "%.1fk", Double(n) / 1000) }
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }
    
    private func copyUserId() {
        if let code = userManager.userCode {
            UIPasteboard.general.string = code
            copiedId = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copiedId = false
            }
        }
    }
    
    private var profileTripsContent: some View {
        Group {
            if isLoadingTrips {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if myTrips.isEmpty {
                Text("profile_page.my_trips_hint".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(myTrips, id: \.id) { event in
                        if event.deleted != 1 {
                            NavigationLink(destination: EventShareView(event: event).environmentObject(userManager)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(event.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        if !event.date.isEmpty {
                                            Text(event.date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .task(id: selectedTab) {
            if selectedTab == .trips && myTrips.isEmpty {
                await loadMyTrips()
            }
        }
        .refreshable {
            if selectedTab == .trips { await loadMyTrips() }
        }
    }

    private func loadMyTrips() async {
        isLoadingTrips = true
        defer { isLoadingTrips = false }
        do {
            let all = try await EventManager.shared.fetchEvents()
            let mine = all.filter { $0.creatorOpenid == userManager.userOpenId && ($0.deleted ?? 0) != 1 }
            let sorted = mine.sorted { ($0.dateObj ?? .distantPast) > ($1.dateObj ?? .distantPast) }
            await MainActor.run { myTrips = sorted }
        } catch {
            await MainActor.run { myTrips = [] }
        }
    }
    
    private var profileThemesPlaceholder: some View {
        Text("friend_detail.themes_placeholder".localized())
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color(.systemBackground))
            .cornerRadius(12)
    }
    
    private var profileTemplatesPlaceholder: some View {
        Text("friend_detail.templates_placeholder".localized())
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color(.systemBackground))
            .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        PersonalProfileView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
