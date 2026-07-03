//
//  FriendSelectionRow.swift
//  Secalender
//

import SwiftUI

struct FriendSelectionRow: View {
    let friend: FriendEntry
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                // 头像 - 玻璃态效果
                if let photoUrl = friend.photoUrl, !photoUrl.isEmpty {
                    AsyncImage(url: URL(string: photoUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Material.ultraThinMaterial)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                } else {
                    Circle()
                        .fill(Material.ultraThinMaterial)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 24))
                        )
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(friend.name ?? friend.alias ?? "未知用户")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let email = friend.email, !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 选择指示器 - 玻璃态效果
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 32, height: 32)
                    } else {
                    Circle()
                            .fill(Material.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else {
                        Circle()
                            .stroke(.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}