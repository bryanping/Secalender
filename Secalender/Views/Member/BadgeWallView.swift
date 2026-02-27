//
//  BadgeWallView.swift
//  Secalender
//
//  完整勳章牆：成就 + 獎章等級（銅/銀/金/白金）+ 隱藏勳章
//

import SwiftUI

struct BadgeWallView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @StateObject private var influenceManager = InfluenceDataManager.shared
    
    @State private var selectedFilter: BadgeFilter = .all
    
    enum BadgeFilter: String, CaseIterable {
        case all = "badge.filter_all"
        case unlocked = "badge.filter_unlocked"
        case locked = "badge.filter_locked"
        case hidden = "badge.filter_hidden"
    }
    
    private var progressList: [AchievementProgress] {
        influenceManager.achievementProgress(for: userManager.userOpenId)
    }
    
    private var filteredList: [AchievementProgress] {
        switch selectedFilter {
        case .all: return progressList
        case .unlocked: return progressList.filter { $0.isUnlocked }
        case .locked: return progressList.filter { !$0.isUnlocked && !$0.definition.isHidden }
        case .hidden: return progressList.filter { $0.definition.isHidden }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryHeader
                filterChips
                medalLegend
                badgeGrid
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("badge.wall_title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await influenceManager.load(for: userManager.userOpenId)
        }
        .refreshable {
            await influenceManager.load(for: userManager.userOpenId)
        }
    }
    
    private var summaryHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("member.achievements_unlocked".localized(with: progressList.filter { $0.isUnlocked }.count, progressList.count))
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("badge.wall_subtitle".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "medal.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#CD7F32") ?? .orange, Color(hex: "#FFD700") ?? .yellow],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BadgeFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue.localized())
                            .font(.subheadline)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? Color.blue : Color(.systemGray6))
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var medalLegend: some View {
        HStack(spacing: 16) {
            ForEach(Medal.allCases, id: \.rawValue) { medal in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: medal.colorHex) ?? .gray)
                        .frame(width: 12, height: 12)
                    Text(medal.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var badgeGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(filteredList) { prog in
                badgeCard(prog)
            }
        }
    }
    
    private func badgeCard(_ prog: AchievementProgress) -> some View {
        let isHidden = prog.definition.isHidden && !prog.isUnlocked
        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(cardBackground(unlocked: prog.isUnlocked, hidden: isHidden))
                    .frame(width: 56, height: 56)
                
                if isHidden {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: prog.definition.icon)
                        .font(.title2)
                        .foregroundColor(prog.isUnlocked ? medalColor(for: prog) : .gray)
                }
                
                if prog.isUnlocked {
                    Circle()
                        .stroke(medalColor(for: prog), lineWidth: 2)
                        .frame(width: 60, height: 60)
                }
            }
            
            Text(isHidden ? "???" : prog.definition.localizedKey.localized())
                .font(.caption2)
                .foregroundColor(prog.isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            if prog.isUnlocked {
                Text("\(prog.current)/\(prog.definition.targetCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if !isHidden {
                ProgressView(value: prog.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func cardBackground(unlocked: Bool, hidden: Bool) -> Color {
        if hidden { return Color.gray.opacity(0.2) }
        if unlocked { return Color.blue.opacity(0.15) }
        return Color.gray.opacity(0.12)
    }
    
    private func medalColor(for prog: AchievementProgress) -> Color {
        // 依進度給予獎章顏色（簡化：達標給金，未達標給銅）
        if prog.progress >= 1.0 { return Color(hex: "#FFD700") ?? .yellow }
        if prog.progress >= 0.7 { return Color(hex: "#C0C0C0") ?? .gray }
        if prog.progress >= 0.3 { return Color(hex: "#CD7F32") ?? .orange }
        return Color.blue
    }
}

#Preview {
    NavigationView {
        BadgeWallView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
