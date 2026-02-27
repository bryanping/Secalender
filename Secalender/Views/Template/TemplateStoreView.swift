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

/// 模版市集主分類：主題 vs 行程
enum TemplateStoreMainTab: Int, CaseIterable, Hashable {
    case themes = 0      // 精選主題
    case itineraries = 1 // 精選行程
}

struct TemplateStoreView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @StateObject private var vm = TemplateStoreViewModel()
    @State private var selectedMainTab: TemplateStoreMainTab = .themes
    @State private var isSearchExpanded = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            searchAndFilterBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            
            // 主題／行程切換（可左右滑動）
            mainTabPicker
                .padding(.bottom, 12)
            
            TabView(selection: $selectedMainTab) {
                mainTabContent(for: .themes)
                    .tag(TemplateStoreMainTab.themes)
                
                mainTabContent(for: .itineraries)
                    .tag(TemplateStoreMainTab.itineraries)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        .dismissKeyboardOnTap()
        .task(id: userManager.userOpenId) {
            let uid = userManager.userOpenId
            guard !uid.isEmpty else { return }
            await vm.load(userId: uid)
        }
        .refreshable {
            await vm.refresh(userId: userManager.userOpenId)
        }
    }
}

// MARK: - Search & Filter Bar（放大鏡點選後展開，如快速主題）
private extension TemplateStoreView {
    @ViewBuilder
    var searchAndFilterBar: some View {
        VStack(spacing: 0) {
            // 收合時：分類標籤 + 放大鏡按鈕
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(StoreTemplateCategory.allCases, id: \.self) { category in
                            categoryChip(category)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isSearchExpanded = true
                        isSearchFocused = true
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            
            // 展開時：搜尋欄 + 篩選（國家、天數）
            if isSearchExpanded {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("template_store.search_placeholder".localized(), text: $vm.searchText)
                                .focused($isSearchFocused)
                                .textFieldStyle(.plain)
                                .font(.system(size: 15))
                        }
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        Button(action: {
                            hideKeyboard()
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isSearchExpanded = false
                                vm.searchText = ""
                                isSearchFocused = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 國家篩選
                    countryFilterRow
                    
                    // 天數篩選
                    daysFilterRow
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    func categoryChip(_ category: StoreTemplateCategory) -> some View {
        let title: String = {
            switch category {
            case .all: return "template_store.category.all".localized()
            case .popular: return "template_store.category.popular".localized()
            case .newArrivals: return "template_store.category.new".localized()
            case .creators: return "template_store.category.creators".localized()
            case .themes: return "template_store.category.themes".localized()
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
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    var countryFilterRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("template_store.filter.country".localized())
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TemplateCountryFilter.allCases, id: \.self) { opt in
                        Button(action: { vm.selectedCountry = opt }) {
                            Text(countryFilterTitle(opt))
                                .font(.system(size: 13, weight: vm.selectedCountry == opt ? .semibold : .medium))
                                .foregroundColor(vm.selectedCountry == opt ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(vm.selectedCountry == opt ? Color.blue : Color(.systemGray6))
                                .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    var daysFilterRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("template_store.filter.days".localized())
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TemplateDaysFilter.allCases, id: \.self) { opt in
                        Button(action: { vm.selectedDays = opt }) {
                            Text(daysFilterTitle(opt))
                                .font(.system(size: 13, weight: vm.selectedDays == opt ? .semibold : .medium))
                                .foregroundColor(vm.selectedDays == opt ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(vm.selectedDays == opt ? Color.blue : Color(.systemGray6))
                                .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    func countryFilterTitle(_ filter: TemplateCountryFilter) -> String {
        switch filter {
        case .all: return "template_store.filter.all".localized()
        case .japan: return "日本"
        case .taiwan: return "台灣"
        case .usa: return "美國"
        case .france: return "法國"
        case .italy: return "義大利"
        case .spain: return "西班牙"
        case .uk: return "英國"
        case .korea: return "韓國"
        }
    }
    
    func daysFilterTitle(_ filter: TemplateDaysFilter) -> String {
        switch filter {
        case .all: return "template_store.filter.all".localized()
        case .oneToTwo: return "template_store.filter.days_1_2".localized()
        case .threeToFour: return "template_store.filter.days_3_4".localized()
        case .fivePlus: return "template_store.filter.days_5_plus".localized()
        }
    }
}

// MARK: - Main Tab Picker（精選主題／精選行程）
private extension TemplateStoreView {
    var mainTabPicker: some View {
        Picker("", selection: $selectedMainTab) {
            ForEach(TemplateStoreMainTab.allCases, id: \.self) { tab in
                Text(mainTabTitle(for: tab)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }
    
    func mainTabTitle(for tab: TemplateStoreMainTab) -> String {
        switch tab {
        case .themes: return "template_store.main_tab.themes".localized()
        case .itineraries: return "template_store.main_tab.itineraries".localized()
        }
    }
    
    @ViewBuilder
    func mainTabContent(for tab: TemplateStoreMainTab) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if vm.isLoading && vm.templates.isEmpty {
                    loadingView
                } else if let err = vm.errorMessage, !err.isEmpty {
                    errorView
                } else if tab == .themes {
                    themesSection
                } else {
                    itinerariesSection
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
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
            case .themes: return "template_store.category.themes".localized()
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

// MARK: - Themes Section（精選主題、熱門主題、最新主題）
private extension TemplateStoreView {
    @ViewBuilder
    var themesSection: some View {
        if !vm.searchText.isEmpty {
            searchResultsSection(for: .themes)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                sectionBlock(titleKey: "template_store.section.featured_themes", templates: vm.featuredTemplates(for: .themes), isHorizontal: true)
                sectionBlock(titleKey: "template_store.section.popular_themes", templates: vm.popularTemplates(for: .themes), isHorizontal: false)
                sectionBlock(titleKey: "template_store.section.new_themes", templates: vm.newTemplates(for: .themes), isHorizontal: false)
            }
        }
    }
}

// MARK: - Itineraries Section（精選行程、熱門行程、最新行程）
private extension TemplateStoreView {
    @ViewBuilder
    var itinerariesSection: some View {
        if !vm.searchText.isEmpty {
            searchResultsSection(for: .itineraries)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                sectionBlock(titleKey: "template_store.section.featured_itineraries", templates: vm.featuredTemplates(for: .itineraries), isHorizontal: true)
                sectionBlock(titleKey: "template_store.section.popular_itineraries", templates: vm.popularTemplates(for: .itineraries), isHorizontal: false)
                sectionBlock(titleKey: "template_store.section.new_itineraries", templates: vm.newTemplates(for: .itineraries), isHorizontal: false)
            }
        }
    }
}

// MARK: - Section Block（App Store 風格：標題＋箭頭、橫滑提示、卡片／列表）
private extension TemplateStoreView {
    @ViewBuilder
    func sectionBlock(titleKey: String, templates: [StoreTemplate], isHorizontal: Bool) -> some View {
        if !templates.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // App Store 風格：區塊標題＋右箭頭（＞）
                HStack(spacing: 4) {
                    Text(titleKey.localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                
                // 橫向滾動區塊：顯示「向左滑動，查看更多」提示
                if isHorizontal {
                    Text("template_store.swipe_hint".localized())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(templates) { template in
                                appStoreStyleRow(template)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(templates) { template in
                            NavigationLink(destination: detailDestination(template)) {
                                templateCard(template)
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
    
    /// App Store 風格列表列：圖標左、標題＋描述中、取得按鈕右
    func appStoreStyleRow(_ template: StoreTemplate) -> some View {
        NavigationLink(destination: detailDestination(template)) {
            HStack(spacing: 12) {
                // 左側圖標（圓角方形）
                coverPlaceholder(template)
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)
                    .clipped()
                
                // 中間：標題＋描述
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 右側：取得按鈕
                Text(vm.isPurchased(template) ? "template_store.opened".localized() : "template_store.get".localized())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(12)
            .frame(width: 280)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    func searchResultsSection(for tab: TemplateStoreMainTab) -> some View {
        let filtered = vm.filteredTemplates(for: tab)
        VStack(alignment: .leading, spacing: 16) {
            Text("template_store.results_count".localized(with: filtered.count))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            if filtered.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(filtered) { template in
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

// MARK: - Featured Card & Template Card
private extension TemplateStoreView {
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

// MARK: - Template Card
private extension TemplateStoreView {
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

