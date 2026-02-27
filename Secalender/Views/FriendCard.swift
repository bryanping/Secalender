//
//  FriendCard.swift
//  Secalender
//
//  好友卡片：Avatar + Name + Lv + 認證、小標、3 小數據、按鈕
//  對齊創作者設計風格
//

import SwiftUI

/// 好友卡片擴展數據（可選，用於顯示統計與認證）
struct FriendCardStats {
    var level: Int = 1
    var isVerified: Bool = false
    var isOfficial: Bool = false
    var region: String?
    var lastActive: String?
    var publicPlansCount: Int = 0
    var templateCount: Int = 0
    var likesCount: Int = 0
}

/// 好友卡片 - 創作者風格
/// Avatar + Name + Lv + 認證 | 小標（地區/最近活躍）| 3 小數據 | 按鈕
struct FriendCard: View {
    let friend: FriendEntry
    var stats: FriendCardStats = FriendCardStats()
    var onViewProfile: () -> Void
    var onCompareAvailability: (() -> Void)?
    var onInviteEvent: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 頂部：頭像 + 名稱行
            HStack(alignment: .top, spacing: 12) {
                avatarView
                
                VStack(alignment: .leading, spacing: 6) {
                    // Name + Lv + 認證
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // Lv chip
                        Text("Lv\(stats.level)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(6)
                        
                        if stats.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        if stats.isOfficial {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // 小標：地區 / 最近活躍
                    if let region = stats.region, !region.isEmpty {
                        Label(region, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let lastActive = stats.lastActive, !lastActive.isEmpty {
                        Label(lastActive, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // 3 小數據（選 2～3）
            HStack(spacing: 16) {
                statPill(icon: "map.fill", value: stats.publicPlansCount, label: "friend_card.public_plans".localized())
                statPill(icon: "doc.text.fill", value: stats.templateCount, label: "friend_card.templates".localized())
                statPill(icon: "heart.fill", value: stats.likesCount, label: "friend_card.likes".localized())
            }
            
            // 按鈕列
            HStack(spacing: 8) {
                Button(action: onViewProfile) {
                    Label("friend_card.view_profile".localized(), systemImage: "person.circle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                if let onCompare = onCompareAvailability {
                    Button(action: onCompare) {
                        Label("friend_card.compare_slots".localized(), systemImage: "calendar.badge.clock")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.12))
                            .foregroundColor(.green)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                
                if let onInvite = onInviteEvent {
                    Button(action: onInvite) {
                        Label("friend_card.invite_event".localized(), systemImage: "calendar.badge.plus")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.12))
                            .foregroundColor(.orange)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    private var displayName: String {
        friend.alias ?? friend.name ?? friend.email ?? "friends.unknown".localized()
    }
    
    private var avatarView: some View {
        Group {
            if let urlStr = friend.photoUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure, .empty:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(displayName.prefix(1))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            )
    }
    
    private func statPill(icon: String, value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
#Preview {
    FriendCard(
        friend: FriendEntry(
            id: "1",
            alias: "小明",
            name: "小明",
            email: "test@example.com",
            photoUrl: nil,
            gender: nil
        ),
        stats: FriendCardStats(
            level: 5,
            isVerified: true,
            region: "台北",
            lastActive: "2 小時前",
            publicPlansCount: 12,
            templateCount: 3,
            likesCount: 28
        ),
        onViewProfile: {},
        onCompareAvailability: {},
        onInviteEvent: {}
    )
    .padding()
}
