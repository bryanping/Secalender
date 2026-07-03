//
//  ContentBatchManagementView.swift
//  Secalender
//
//  內容批量管理：待發布（草稿聚合）、下架、改可見性、改標籤
//

import SwiftUI

enum BatchActionType: String, CaseIterable {
    case publish = "assets.batch.publish"
    case unpublish = "assets.batch.unpublish"
    case changeVisibility = "assets.batch.visibility"
    case changeTags = "assets.batch.tags"
}

struct ContentBatchManagementView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var selectedItems: Set<String> = []
    @State private var isSelectMode = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 說明
                VStack(alignment: .leading, spacing: 8) {
                    Label("assets.batch.hint_title".localized(), systemImage: "info.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Text("assets.batch.hint_desc".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(12)
                
                // 批量操作按鈕
                VStack(alignment: .leading, spacing: 12) {
                    Text("assets.batch.actions".localized())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        batchActionCard(icon: "square.and.arrow.up", title: BatchActionType.publish.rawValue.localized(), color: .green)
                        batchActionCard(icon: "arrow.down.circle", title: BatchActionType.unpublish.rawValue.localized(), color: .orange)
                        batchActionCard(icon: "eye", title: BatchActionType.changeVisibility.rawValue.localized(), color: .blue)
                        batchActionCard(icon: "tag", title: BatchActionType.changeTags.rawValue.localized(), color: .purple)
                    }
                }
                
                // 待發布草稿聚合（佔位）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("assets.batch.pending_drafts".localized())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("assets.batch.no_pending".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.assets_batch_manage".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func batchActionCard(icon: String, title: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        ContentBatchManagementView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
