//
//  SocialAssetsManagementView.swift
//  Secalender
//
//  社交資產管理：追蹤、粉絲、好友、邀請與請求、黑名單、私訊偏好
//

import SwiftUI

enum SocialAssetSection: String, CaseIterable {
    case following = "member.community_following"
    case followers = "member.community_followers"
    case friends = "member.community_friends"
    case invites = "member.community_invites"
    case blocklist = "member.community_blocklist"
    case messagePrefs = "member.community_message_prefs"
    
    var icon: String {
        switch self {
        case .following: return "person.2.fill"
        case .followers: return "person.3.fill"
        case .friends: return "person.2.circle.fill"
        case .invites: return "envelope.badge.fill"
        case .blocklist: return "hand.raised.fill"
        case .messagePrefs: return "message.fill"
        }
    }
}

struct SocialAssetsManagementView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var pendingCount: Int = 0
    
    var body: some View {
        List {
            ForEach(SocialAssetSection.allCases, id: \.self) { section in
                NavigationLink(destination: socialAssetDetailView(for: section)) {
                    HStack {
                        Image(systemName: section.icon)
                            .foregroundColor(.blue)
                            .frame(width: 24, alignment: .center)
                        Text(section.rawValue.localized())
                            .foregroundColor(.primary)
                        Spacer()
                        if section == .invites && pendingCount > 0 {
                            Text("\(pendingCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("member.community_social".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func socialAssetDetailView(for section: SocialAssetSection) -> some View {
        switch section {
        case .following:
            FollowingManagementView()
        case .followers:
            FollowersManagementView()
        case .friends:
            MyFriendListView()
        case .invites:
            ReceivedFriendRequestsView()
        case .blocklist:
            BlocklistManagementView()
        case .messagePrefs:
            MessagePreferencesView()
        }
    }
}

struct FollowingManagementView: View {
    var body: some View {
        List {
            Text("member.community_following".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("member.community_following".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FollowersManagementView: View {
    var body: some View {
        List {
            Text("member.community_followers".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("member.community_followers".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BlocklistManagementView: View {
    var body: some View {
        List {
            Text("member.community_blocklist".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("member.community_blocklist".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MessagePreferencesView: View {
    @State private var allowFriendsOnly = true
    @State private var allowFollowers = false
    
    var body: some View {
        Form {
            Section(header: Text("member.message_prefs_header".localized())) {
                Toggle("member.message_prefs_friends".localized(), isOn: $allowFriendsOnly)
                Toggle("member.message_prefs_followers".localized(), isOn: $allowFollowers)
            }
        }
        .navigationTitle("member.community_message_prefs".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        SocialAssetsManagementView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
