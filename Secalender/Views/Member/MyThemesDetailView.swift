//
//  MyThemesDetailView.swift
//  Secalender
//
//  我的主題：草稿/已發佈
//  對齊創作者設計
//

import SwiftUI

enum ThemeVisibilityFilter: String, CaseIterable {
    case all = "assets.themes.all"
    case draft = "assets.themes.draft"
    case published = "assets.themes.published"
    
    var localizedKey: String { rawValue }
}

struct MyThemesDetailView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var selectedFilter: ThemeVisibilityFilter = .all
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(ThemeVisibilityFilter.allCases, id: \.self) { filter in
                            Button(action: { selectedFilter = filter }) {
                                Text(filter.localizedKey.localized())
                                    .font(.subheadline)
                                    .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                    .foregroundColor(selectedFilter == filter ? .blue : .secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.blue.opacity(0.12) : Color(.systemGray6))
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                VStack(spacing: 20) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("assets.themes.empty_hint".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    NavigationLink(destination: TravelTemplateView().environmentObject(userManager)) {
                        Text("assets.themes.create_action".localized())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.assets_themes".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        MyThemesDetailView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
