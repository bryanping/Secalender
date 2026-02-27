//
//  RecentViewsDetailView.swift
//  Secalender
//
//  最近瀏覽：行程、主題、模板
//

import SwiftUI

struct RecentViewsDetailView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.4))
                Text("assets.recent.empty_hint".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 80)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.assets_recent".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        RecentViewsDetailView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
