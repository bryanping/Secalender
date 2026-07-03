//
//  CommunityInfluenceSection.swift
//  Secalender
//
//  社群與影響力：數據分析、成就、等級、社交資產
//

import SwiftUI

struct CommunityInfluenceSection: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("member.community_influence_title".localized())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                NavigationLink(destination: CommunityInfluenceCenterView()) {
                    communityRow(icon: "chart.bar.fill", title: "member.community_analytics".localized(), hint: "member.community_analytics_hint".localized())
                }
                .buttonStyle(.plain)
                
                Divider().padding(.leading, 44)
                
                NavigationLink(destination: AchievementsContentView()) {
                    communityRow(icon: "medal.fill", title: "member.community_achievements".localized(), hint: nil)
                }
                .buttonStyle(.plain)
                
                Divider().padding(.leading, 44)
                
                NavigationLink(destination: LevelBenefitsView()) {
                    communityRow(icon: "star.circle.fill", title: "member.community_level".localized(), hint: "member.level_badge".localized(with: 24, "member.level_creator".localized()))
                }
                .buttonStyle(.plain)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
    }
    
    private func communityRow(icon: String, title: String, hint: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            Spacer()
            if let hint = hint, !hint.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
    }
}

struct LevelBenefitsPlaceholderView: View {
    var body: some View {
        Text("member.community_level".localized())
            .navigationTitle("member.community_level".localized())
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct SocialAssetsPlaceholderView: View {
    var body: some View {
        List {
            Text("member.community_following".localized())
            Text("member.community_followers".localized())
            Text("member.community_friends".localized())
            Text("member.community_invites".localized())
            Text("member.community_blocklist".localized())
        }
        .navigationTitle("member.community_social".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CommunityInfluenceSection()
        .environmentObject(FirebaseUserManager.shared)
        .padding()
}
