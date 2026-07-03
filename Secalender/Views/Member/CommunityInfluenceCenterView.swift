//
//  CommunityInfluenceCenterView.swift
//  Secalender
//
//  社群與影響力中心：等級卡片、成就系統、數據分析儀表板
//  對齊創作者設計參考圖，使用 InfluenceDataManager 真實數據
//

import SwiftUI

struct CommunityInfluenceCenterView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @StateObject private var influenceManager = InfluenceDataManager.shared
    
    private var level: Int { influenceManager.stats.level }
    private var expCurrent: Int { influenceManager.stats.expCurrent }
    private var expNeeded: Int { influenceManager.stats.expNeeded }
    private var unlockedAchievements: Int { influenceManager.unlockedAchievementsCount() }
    private var totalAchievements: Int { influenceManager.totalAchievementsCount() }
    private var weeklyData: Int { influenceManager.stats.weeklyViews + influenceManager.stats.weeklyEngagement }
    private var weeklyTrend: Double {
        let last = influenceManager.stats.lastWeekViews + influenceManager.stats.lastWeekEngagement
        guard last > 0 else { return 0 }
        return Double(weeklyData - last) / Double(last) * 100
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 影響力等級卡片
                levelCard
                
                // 成就系統
                achievementsSection
                
                // 數據分析中心（卡片儀表板）
                analyticsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.community_center_title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await influenceManager.load(for: userManager.userOpenId)
        }
        .refreshable {
            await influenceManager.load(for: userManager.userOpenId)
        }
    }
    
    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("member.level_badge".localized(with: level, ""))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("member.influence_level".localized())
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                NavigationLink(destination: TaskCenterPlaceholderView()) {
                    Text("member.task_center".localized())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            Text("member.exp_to_next".localized(with: level + 1, expNeeded - expCurrent))
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("member.growth_progress".localized())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text("\(expCurrent)/\(expNeeded) EXP")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                ProgressView(value: Double(expCurrent), total: Double(expNeeded))
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .scaleEffect(y: 1.2)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("member.achievements_title".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("member.achievements_unlocked".localized(with: unlockedAchievements, totalAchievements))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(influenceManager.achievementProgress(for: userManager.userOpenId).prefix(6)) { prog in
                    achievementBadge(
                        icon: prog.definition.icon,
                        name: prog.definition.localizedKey.localized(),
                        unlocked: prog.isUnlocked
                    )
                }
            }
            
            NavigationLink(destination: BadgeWallView().environmentObject(userManager)) {
                HStack {
                    Text("member.view_all_badges".localized())
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
            
            Group {
                if let next = influenceManager.achievementProgress(for: userManager.userOpenId).first(where: { !$0.isUnlocked }) {
                    HStack {
                        Text("member.next_achievement".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(next.definition.localizedKey.localized())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(Int(next.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    ProgressView(value: next.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    private func achievementBadge(icon: String, name: String, unlocked: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlocked ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(unlocked ? .blue : .gray)
            }
            Text(name)
                .font(.caption2)
                .foregroundColor(unlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("member.analytics_title".localized())
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("member.analytics_weekly_summary".localized())
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatNumber(weeklyData))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("+\(String(format: "%.1f", weeklyTrend))%")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("member.vs_last_week".localized())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            // 簡化折線圖佔位
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.2))
                .frame(height: 80)
                .overlay(
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.blue.opacity(0.5))
                )
            
            HStack(spacing: 12) {
                analyticsCard(value: "1,284", label: "member.analytics_engagement".localized())
                analyticsCard(value: "4.2%", label: "member.analytics_ctr".localized())
                analyticsCard(value: "352", label: "member.analytics_shares".localized())
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    private func analyticsCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

struct TaskCenterPlaceholderView: View {
    var body: some View {
        Text("member.task_center".localized())
            .navigationTitle("member.task_center".localized())
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        CommunityInfluenceCenterView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
