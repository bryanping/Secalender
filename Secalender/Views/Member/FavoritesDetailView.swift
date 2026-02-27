//
//  FavoritesDetailView.swift
//  Secalender
//
//  收藏：收藏的行程、主題、模板
//

import SwiftUI

enum FavoritesTab: String, CaseIterable {
    case plans = "assets.favorites.plans"
    case themes = "assets.favorites.themes"
    case templates = "assets.favorites.templates"
}

struct FavoritesDetailView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var selectedTab: FavoritesTab = .plans
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(FavoritesTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
                                Text(tab.rawValue.localized())
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? Color.blue.opacity(0.12) : Color(.systemGray6))
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                VStack(spacing: 20) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("assets.favorites.empty_hint".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.assets_favorites".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        FavoritesDetailView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
