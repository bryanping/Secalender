//
//  CreatorProfileView.swift
//  Secalender
//
//  博主主頁：顯示創作者資訊、關注按鈕、其全部付費／免費模版行程
//

import SwiftUI

/// 創作者主頁
struct CreatorProfileView: View {
    let creator: TemplateCreator
    let templates: [StoreTemplate]
    let isPurchased: (StoreTemplate) -> Bool
    let onFollow: () -> Void
    let onUnfollow: () -> Void
    
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var isFollowing: Bool
    
    init(
        creator: TemplateCreator,
        templates: [StoreTemplate],
        isFollowing: Bool,
        isPurchased: @escaping (StoreTemplate) -> Bool,
        onFollow: @escaping () -> Void,
        onUnfollow: @escaping () -> Void
    ) {
        self.creator = creator
        self.templates = templates
        self.isPurchased = isPurchased
        self.onFollow = onFollow
        self.onUnfollow = onUnfollow
        _isFollowing = State(initialValue: isFollowing)
    }
    
    enum TemplateFilter: String, CaseIterable {
        case all
        case free
        case paid
    }
    
    @State private var selectedFilter: TemplateFilter = .all
    
    private var filteredTemplates: [StoreTemplate] {
        switch selectedFilter {
        case .all: return templates
        case .free: return templates.filter { $0.isFree }
        case .paid: return templates.filter { !$0.isFree }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                creatorHeader
                templateFilterTabs
                templatesGrid
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(creator.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Creator Header
private extension CreatorProfileView {
    var creatorHeader: some View {
        VStack(spacing: 16) {
            avatarView
            
            Text(creator.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let bio = creator.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            HStack(spacing: 24) {
                statItem(value: "\(creator.followerCount)", label: "creator.followers".localized())
                statItem(value: "\(creator.templateCount)", label: "creator.templates".localized())
            }
            .padding(.vertical, 8)
            
            followButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
    }
    
    var avatarView: some View {
        Group {
            if let urlString = creator.avatarURL, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure, .empty: avatarPlaceholder
                    @unknown default: avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
    }
    
    var avatarPlaceholder: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(creator.name.prefix(1))
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        )
    }
    
    func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    var followButton: some View {
        Button(action: {
            isFollowing.toggle()
            if isFollowing {
                onFollow()
            } else {
                onUnfollow()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: isFollowing ? "person.fill.checkmark" : "person.badge.plus")
                Text(isFollowing ? "creator.following".localized() : "creator.follow".localized())
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(isFollowing ? .secondary : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isFollowing {
                        Color.gray.opacity(0.2)
                    } else {
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 280)
    }
}

// MARK: - Template Filter Tabs
private extension CreatorProfileView {
    var templateFilterTabs: some View {
        HStack(spacing: 12) {
            ForEach(TemplateFilter.allCases, id: \.self) { filter in
                filterButton(filter)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    func filterButton(_ filter: TemplateFilter) -> some View {
        let title: String = {
            switch filter {
            case .all: return "creator.filter.all".localized()
            case .free: return "creator.filter.free".localized()
            case .paid: return "creator.filter.paid".localized()
            }
        }()
        let count: Int = {
            switch filter {
            case .all: return templates.count
            case .free: return templates.filter { $0.isFree }.count
            case .paid: return templates.filter { !$0.isFree }.count
            }
        }()
        let isSelected = selectedFilter == filter
        
        return Button(action: { selectedFilter = filter }) {
            Text("\(title) (\(count))")
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.15))
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Templates Grid
private extension CreatorProfileView {
    var templatesGrid: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if filteredTemplates.isEmpty {
                emptyTemplatesView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(filteredTemplates) { template in
                        NavigationLink(destination: templateDetailDestination(template)) {
                            creatorTemplateCard(template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
    
    func creatorTemplateCard(_ template: StoreTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            coverPlaceholder(template)
                .frame(height: 90)
                .clipped()
            
            Text(template.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            HStack(spacing: 6) {
                Label("\(template.daysCount)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Group {
                    if template.isFree {
                        Text("template_detail.free".localized())
                            .foregroundColor(.blue)
                    } else {
                        Text("template_store.price_format".localized(with: template.price))
                            .foregroundColor(.green)
                    }
                }
                .font(.caption)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
    
    func coverPlaceholder(_ template: StoreTemplate) -> some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.6), Color.teal.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "map.fill")
                .font(.title)
                .foregroundColor(.white.opacity(0.6))
        )
        .frame(maxWidth: .infinity)
        .cornerRadius(8)
    }
    
    func templateDetailDestination(_ template: StoreTemplate) -> some View {
        TemplateDetailView(
            template: template,
            isPurchased: isPurchased(template)
        )
        .environmentObject(userManager)
    }
    
    var emptyTemplatesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("creator.no_templates".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
