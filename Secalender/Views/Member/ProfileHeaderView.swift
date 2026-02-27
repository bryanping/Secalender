//
//  ProfileHeaderView.swift
//  Secalender
//
//  個人中心頂部：Avatar + Name + ID、地區+簽名、Chips、CTA、Stats
//  對齊創作者設計
//

import SwiftUI

struct ProfileHeaderView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showQRSheet = false
    @State private var showShareSheet = false
    @State private var copiedId = false
    
    // 模擬數據（後續接後端）
    var level: Int { 24 }
    var isVerified: Bool { true }
    var isOfficial: Bool { false }
    var followingCount: Int { 1200 }
    var followersCount: Int { 850 }
    var favoritesCount: Int { 3400 }
    var likesCount: Int { 12000 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 個人中心標題
            Text("member.profile_center_title".localized())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // 頂部：頭像 + 名稱行 + 分享
            HStack(alignment: .top, spacing: 16) {
                avatarView
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(userManager.displayName ?? "member.default_user".localized())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Text("member.user_id".localized() + ": \(userManager.userCode ?? "—")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: copyUserId) {
                            Image(systemName: copiedId ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if let sig = userManager.signature, !sig.isEmpty {
                        Text(sig)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                Spacer(minLength: 0)
                
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // 操作按鈕：編輯資料 + 我的 QR
            HStack(spacing: 12) {
                NavigationLink(destination: EditProfileView().environmentObject(userManager)) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("profile.edit_profile".localized())
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button(action: { showQRSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode")
                            .font(.subheadline)
                        Text("member.my_qr".localized())
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Stats pills: 追蹤｜粉絲｜收藏｜總覽（小卡片風格）
            HStack(spacing: 0) {
                statPill(value: followingCount, label: "member.following".localized())
                statDivider
                statPill(value: followersCount, label: "member.followers".localized())
                statDivider
                statPill(value: favoritesCount, label: "member.favorites".localized())
                statDivider
                statPill(value: likesCount, label: "member.likes".localized())
            }
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showShareSheet) {
            ShareProfileSheetView(userName: userManager.displayName ?? "", userCode: userManager.userCode ?? "")
        }
        .sheet(isPresented: $showQRSheet) {
            QRCodeSheetView(userName: userManager.displayName ?? "", userCode: userManager.userCode ?? "")
        }
    }
    
    private var avatarView: some View {
        Group {
            if let photoUrl = userManager.photoUrl, let url = URL(string: photoUrl) {
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
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .overlay(
            Group {
                if isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(Color.blue))
                        .offset(x: 26, y: 26)
                }
            }
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
                Text((userManager.displayName ?? "?").prefix(1))
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            )
    }
    
    private var statDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 1, height: 28)
    }
    
    private func statPill(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(formatCount(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(label)
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
}

// MARK: - QR Code Sheet（掃碼加好友/看作品）
struct QRCodeSheetView: View {
    let userName: String
    let userCode: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // QR 佔位（可接入真實 QR 生成）
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "qrcode")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                    )
                
                Text(userName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("member.user_id".localized() + ": \(userCode)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("member.qr_hint".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("member.my_qr".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized()) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Share Profile Sheet
struct ShareProfileSheetView: View {
    let userName: String
    let userCode: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("member.share_profile_hint".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    UIPasteboard.general.string = "\(userName) - \(userCode)"
                    dismiss()
                }) {
                    Label("member.copy_profile_link".localized(), systemImage: "link")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding()
            .navigationTitle("member.share_profile".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized()) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ProfileHeaderView()
        .environmentObject(FirebaseUserManager.shared)
        .padding()
}
