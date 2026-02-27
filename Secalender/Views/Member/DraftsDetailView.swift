//
//  DraftsDetailView.swift
//  Secalender
//
//  草稿箱：統一入口，聚合所有草稿
//

import SwiftUI

enum DraftType: String, CaseIterable {
    case plans = "assets.drafts.plans"
    case themes = "assets.drafts.themes"
    case templates = "assets.drafts.templates"
}

struct DraftsDetailView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var selectedType: DraftType = .plans
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(DraftType.allCases, id: \.self) { type in
                            Button(action: { selectedType = type }) {
                                Text(type.rawValue.localized())
                                    .font(.subheadline)
                                    .fontWeight(selectedType == type ? .semibold : .regular)
                                    .foregroundColor(selectedType == type ? .blue : .secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedType == type ? Color.blue.opacity(0.12) : Color(.systemGray6))
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                VStack(spacing: 20) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("assets.drafts.empty_hint".localized())
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
        .navigationTitle("member.assets_drafts".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        DraftsDetailView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
