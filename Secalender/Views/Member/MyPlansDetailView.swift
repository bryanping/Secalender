//
//  MyPlansDetailView.swift
//  Secalender
//
//  我的行程：草稿/已發佈/私密
//  對齊創作者設計
//

import SwiftUI

enum PlanVisibilityFilter: String, CaseIterable {
    case all = "assets.plans.all"
    case draft = "assets.plans.draft"
    case published = "assets.plans.published"
    case private_ = "assets.plans.private"
    
    var localizedKey: String { rawValue }
}

struct MyPlansDetailView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var selectedFilter: PlanVisibilityFilter = .all
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 篩選 Tab
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(PlanVisibilityFilter.allCases, id: \.self) { filter in
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
                
                // 內容區（佔位，後續接 EventManager / 行程 API）
                VStack(spacing: 20) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("assets.plans.empty_hint".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("assets.plans.empty_action".localized())
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.assets_plans".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        MyPlansDetailView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
