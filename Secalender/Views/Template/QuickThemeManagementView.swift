//
//  QuickThemeManagementView.swift
//  Secalender
//
//  快速主題管理：排序、搜索、編輯自定義主題
//

import SwiftUI

struct QuickThemeManagementView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var themeManager = QuickThemeManager.shared
    
    @State private var searchText = ""
    @State private var selectedCategory: QuickThemeCategory = .all
    @State private var themes: [QuickTheme] = []
    @State private var isEditMode = false
    @State private var themeToDelete: QuickTheme?
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索欄
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("quick_theme.search_placeholder".localized(), text: $searchText)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // 分類標籤
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(QuickThemeCategory.allCases, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Text(cat.localizedKey.localized())
                                    .font(.subheadline)
                                    .fontWeight(selectedCategory == cat ? .semibold : .regular)
                                    .foregroundColor(selectedCategory == cat ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == cat ? Color.blue : Color(.systemGray6))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                // 主題列表
                List {
                    ForEach(themes) { theme in
                        HStack(spacing: 12) {
                            Image(systemName: theme.icon)
                                .font(.system(size: 24))
                                .foregroundColor(theme.iconColor)
                                .frame(width: 36, alignment: .center)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(theme.title)
                                    .font(.body)
                                if let ai = theme.aiInstruction, !ai.isEmpty {
                                    Text(ai)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            
                            Spacer()
                            
                            if theme.isBuiltIn {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                if isEditMode {
                                    Button {
                                        themeToDelete = theme
                                        showDeleteAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                } else {
                                    Button {
                                        themeManager.toggleFavorite(themeId: theme.id, userId: userManager.userOpenId)
                                        refreshThemes()
                                    } label: {
                                        Image(systemName: theme.isFavorite ? "heart.fill" : "heart")
                                            .foregroundColor(theme.isFavorite ? .red : .gray)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("quick_theme.manage".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("quick_theme.done".localized()) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "quick_theme.done".localized() : "quick_theme.edit".localized()) {
                        isEditMode.toggle()
                    }
                }
            }
            .onAppear {
                refreshThemes()
            }
            .onChange(of: searchText) { _, _ in refreshThemes() }
            .onChange(of: selectedCategory) { _, _ in refreshThemes() }
            .alert("quick_theme.delete_confirm".localized(), isPresented: $showDeleteAlert) {
                Button("quick_theme.cancel".localized(), role: .cancel) {
                    themeToDelete = nil
                }
                Button("quick_theme.delete".localized(), role: .destructive) {
                    if let t = themeToDelete {
                        themeManager.deleteCustomTheme(id: t.id, userId: userManager.userOpenId)
                        refreshThemes()
                        themeToDelete = nil
                    }
                }
            } message: {
                if let t = themeToDelete {
                    Text("quick_theme.delete_confirm_message".localized(with: t.title))
                }
            }
        }
    }
    
    private func refreshThemes() {
        themes = themeManager.themes(
            for: selectedCategory,
            searchText: searchText,
            userId: userManager.userOpenId
        )
    }
}
