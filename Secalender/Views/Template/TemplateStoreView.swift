//
//  TemplateStoreView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  模板市集頁面 - 商業化設計，含精選、分類、搜尋、卡片式佈局
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TemplateStoreView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @StateObject private var vm = TemplateStoreViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                
                categoryTabs
                    .padding(.bottom, 16)
                
                if vm.isLoading && vm.templates.isEmpty {
                    loadingView
                } else if let err = vm.errorMessage, !err.isEmpty {
                    errorView
                } else if vm.selectedCategory == .creators {
                    creatorsSection
                } else {
                    featuredSection
                    templatesGridSection
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        .task(id: userManager.userOpenId) {
            let uid = userManager.userOpenId
            guard !uid.isEmpty else { return }
            vm.load(userId: uid)
        }
        .refreshable {
            vm.refresh(userId: userManager.userOpenId)
        }
    }
}

// MARK: - Search Bar
private extension TemplateStoreView {
    var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("template_store.search_placeholder".localized(), text: $vm.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
            
            if !vm.searchText.isEmpty {
                Button(action: { vm.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Category Tabs
private extension TemplateStoreView {
    var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(StoreTemplateCategory.allCases, id: \.self) { category in
                    categoryButton(category)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    func categoryButton(_ category: StoreTemplateCategory) -> some View {
        let title: String = {
            switch category {
            case .all: return "template_store.category.all".localized()
            case .popular: return "template_store.category.popular".localized()
            case .newArrivals: return "template_store.category.new".localized()
            case .creators: return "template_store.category.creators".localized()
            case .japan: return "template_store.category.japan".localized()
            case .taiwan: return "template_store.category.taiwan".localized()
            case .korea: return "template_store.category.korea".localized()
            case .europe: return "template_store.category.europe".localized()
            }
        }()
        let isSelected = vm.selectedCategory == category
        return Button(action: { vm.selectedCategory = category }) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        colors: [Color(.systemBackground), Color(.systemBackground)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Creators Section
private extension TemplateStoreView {
    @ViewBuilder
    var creatorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("template_store.creators_title".localized())
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
            
            LazyVStack(spacing: 12) {
                ForEach(vm.creators) { creator in
                    NavigationLink(destination: creatorProfileDestination(creator)) {
                        creatorCard(creator)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
    
    func creatorCard(_ creator: TemplateCreator) -> some View {
        HStack(spacing: 16) {
            creatorAvatar(creator)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(creator.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                if let bio = creator.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 12) {
                    Label("\(creator.followerCount)", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label("\(creator.templateCount)", systemImage: "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
    
    func creatorAvatar(_ creator: TemplateCreator) -> some View {
        Group {
            if let urlString = creator.avatarURL, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure, .empty: creatorAvatarPlaceholder(creator)
                    @unknown default: creatorAvatarPlaceholder(creator)
                    }
                }
            } else {
                creatorAvatarPlaceholder(creator)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }
    
    func creatorAvatarPlaceholder(_ creator: TemplateCreator) -> some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(creator.name.prefix(1))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        )
    }
    
    func creatorProfileDestination(_ creator: TemplateCreator) -> some View {
        CreatorProfileView(
            creator: creator,
            templates: vm.templates(for: creator),
            isFollowing: vm.isFollowing(creator),
            isPurchased: { vm.isPurchased($0) },
            onFollow: { vm.follow(creator) },
            onUnfollow: { vm.unfollow(creator) }
        )
        .environmentObject(userManager)
        .onDisappear { vm.objectWillChange.send() }
    }
}

// MARK: - Featured Section
private extension TemplateStoreView {
    @ViewBuilder
    var featuredSection: some View {
        if !vm.featuredTemplates.isEmpty && vm.searchText.isEmpty && vm.selectedCategory == .all {
            VStack(alignment: .leading, spacing: 12) {
                Text("template_store.featured".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vm.featuredTemplates) { template in
                            NavigationLink(destination: detailDestination(template)) {
                                featuredCard(template)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    func featuredCard(_ template: StoreTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            coverPlaceholder(template)
                .frame(height: 100)
                .clipped()
            
            Text(template.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            HStack {
                if let rating = template.rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                priceLabel(template)
                    .font(.caption)
            }
        }
        .frame(width: 160)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Templates Grid
private extension TemplateStoreView {
    var templatesGridSection: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if !vm.searchText.isEmpty || vm.selectedCategory != .all {
                Text("template_store.results_count".localized(with: vm.filteredTemplates.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
            } else {
                Text("template_store.popular".localized())
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
            }
            
            if vm.filteredTemplates.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(vm.filteredTemplates) { template in
                        NavigationLink(destination: detailDestination(template)) {
                            templateCard(template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
    
    func templateCard(_ template: StoreTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            coverPlaceholder(template)
                .frame(height: 90)
                .clipped()
            
            Text(template.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            if let creator = vm.creators.first(where: { $0.id == template.creatorId }) {
                creatorPill(creator)
            }
            
            HStack(spacing: 6) {
                Label("\(template.daysCount)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let rating = template.rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                priceLabel(template)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
    
    func coverPlaceholder(_ template: StoreTemplate) -> some View {
        Group {
            if let urlString = template.coverImageURL, !urlString.isEmpty,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure, .empty:
                        gradientPlaceholder(template)
                    @unknown default:
                        gradientPlaceholder(template)
                    }
                }
            } else {
                gradientPlaceholder(template)
            }
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(8)
    }
    
    func gradientPlaceholder(_ template: StoreTemplate) -> some View {
        LinearGradient(
            colors: gradientColors(for: template),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "map.fill")
                .font(.title)
                .foregroundColor(.white.opacity(0.6))
        )
    }
    
    func gradientColors(for template: StoreTemplate) -> [Color] {
        let tag = template.tags.first ?? "travel"
        switch tag {
        case "東京", "日本", "京都", "大阪": return [Color.blue.opacity(0.7), Color.purple.opacity(0.5)]
        case "首爾", "韓國": return [Color.red.opacity(0.6), Color.orange.opacity(0.5)]
        case "台北", "台灣", "花蓮": return [Color.green.opacity(0.6), Color.cyan.opacity(0.5)]
        case "巴黎", "歐洲": return [Color.indigo.opacity(0.6), Color.pink.opacity(0.5)]
        default: return [Color.blue.opacity(0.6), Color.teal.opacity(0.5)]
        }
    }
    
    func creatorPill(_ creator: TemplateCreator) -> some View {
        HStack(spacing: 4) {
            Text(creator.name.prefix(1))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.blue.opacity(0.7))
                .clipShape(Circle())
            Text(creator.name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    func priceLabel(_ template: StoreTemplate) -> some View {
        Group {
            if template.isFree {
                Text("template_detail.free".localized())
                    .foregroundColor(.blue)
            } else {
                Text(String(format: "template_store.price_format".localized(), template.price))
                    .foregroundColor(.green)
            }
        }
    }
    
    func detailDestination(_ template: StoreTemplate) -> some View {
        let creator = template.creatorId.flatMap { cid in vm.creators.first(where: { $0.id == cid }) }
        return TemplateDetailView(
            template: template,
            creator: creator,
            creatorTemplates: creator.map { vm.templates(for: $0) } ?? [],
            isPurchased: vm.isPurchased(template),
            isFollowing: creator.map { vm.isFollowing($0) } ?? false,
            onFollow: creator.map { c in { vm.follow(c) } } ?? {},
            onUnfollow: creator.map { c in { vm.unfollow(c) } } ?? {}
        )
        .environmentObject(userManager)
        .onDisappear {
            vm.objectWillChange.send()
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("template_store.empty".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
    
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("template_store.loading".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(vm.errorMessage ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 24)
    }
}

