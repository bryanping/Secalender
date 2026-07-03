//
//  MemberAssetsSection.swift
//  Secalender
//
//  我的資產：行程、主題、模板、收藏、最近瀏覽、草稿箱、內容管理
//

import SwiftUI

struct MemberAssetsSection: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("member.assets_title".localized())
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // 2x2 網格：我的行程、主題、模板、草稿箱
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                NavigationLink(destination: MyPlansDetailView().environmentObject(userManager)) {
                    assetItemContent(icon: "map.fill", label: "member.assets_plans".localized())
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: MyThemesDetailView().environmentObject(userManager)) {
                    assetItemContent(icon: "bookmark.fill", label: "member.assets_themes".localized())
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: MyTemplatesDetailView().environmentObject(userManager)) {
                    assetItemContent(icon: "square.grid.2x2.fill", label: "member.assets_templates".localized())
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: DraftsDetailView().environmentObject(userManager)) {
                    assetItemContent(icon: "tray.fill", label: "member.assets_drafts".localized())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
    
    private func assetItemContent(icon: String, label: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.blue)
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    MemberAssetsSection()
        .padding()
}
