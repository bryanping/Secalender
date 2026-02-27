//
//  TemplateStoreViewModel.swift
//  Secalender
//
//  模板市集 ViewModel：資料載入、分類篩選、搜尋、購買狀態
//

import Foundation
import SwiftUI

/// 天數篩選選項
enum TemplateDaysFilter: String, CaseIterable {
    case all
    case oneToTwo   // 1-2天
    case threeToFour // 3-4天
    case fivePlus   // 5天以上
}

/// 國家篩選（與模板資料的 country 對應）
enum TemplateCountryFilter: String, CaseIterable {
    case all
    case japan
    case taiwan
    case usa
    case france
    case italy
    case spain
    case uk
    case korea
}

@MainActor
final class TemplateStoreViewModel: ObservableObject {
    @Published var templates: [StoreTemplate] = []
    @Published var featuredTemplates: [StoreTemplate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = "" {
        didSet { applyFilters() }
    }
    @Published var selectedCategory: StoreTemplateCategory = .all {
        didSet { applyFilters() }
    }
    @Published var selectedCountry: TemplateCountryFilter = .all {
        didSet { applyFilters() }
    }
    @Published var selectedDays: TemplateDaysFilter = .all {
        didSet { applyFilters() }
    }
    
    /// 篩選後的模板列表
    @Published var filteredTemplates: [StoreTemplate] = []
    
    /// 創作者列表（用於博主分類）
    @Published var creators: [TemplateCreator] = []
    
    private var userId: String = ""
    
    func load(userId: String, isRefresh: Bool = false) async {
        guard !userId.isEmpty else { return }
        self.userId = userId
        if !isRefresh {
            isLoading = true
        }
        errorMessage = nil
        do {
            let all = try await APIClient.shared.fetchTemplates()
            templates = all
            featuredTemplates = all.filter { $0.isFeatured }
            creators = Self.mockCreators()
            applyFilters()
        } catch {
            // 下拉刷新時 view 重繪會取消 task，導致 URLError.cancelled，不應顯示給用戶
            if (error as NSError).domain == NSURLErrorDomain,
               (error as NSError).code == NSURLErrorCancelled {
                // 保持原有資料與狀態，不設定 errorMessage
            } else {
                errorMessage = error.localizedDescription
            }
        }
        if !isRefresh {
            isLoading = false
        }
    }
    
    func refresh(userId: String) async {
        await load(userId: userId, isRefresh: true)
    }
    
    func isPurchased(_ template: StoreTemplate) -> Bool {
        guard !userId.isEmpty else { return false }
        return TemplatePurchaseManager.shared.isPurchased(templateId: template.id, for: userId)
    }
    
    func markAsPurchased(_ template: StoreTemplate) {
        guard !userId.isEmpty else { return }
        TemplatePurchaseManager.shared.markAsPurchased(templateId: template.id, for: userId)
        objectWillChange.send()
    }
    
    // MARK: - 創作者／博主
    
    func isFollowing(_ creator: TemplateCreator) -> Bool {
        guard !userId.isEmpty else { return false }
        return CreatorFollowManager.shared.isFollowing(creatorId: creator.id, for: userId)
    }
    
    func follow(_ creator: TemplateCreator) {
        guard !userId.isEmpty else { return }
        CreatorFollowManager.shared.follow(creatorId: creator.id, for: userId)
        objectWillChange.send()
    }
    
    func unfollow(_ creator: TemplateCreator) {
        guard !userId.isEmpty else { return }
        CreatorFollowManager.shared.unfollow(creatorId: creator.id, for: userId)
        objectWillChange.send()
    }
    
    func templates(for creator: TemplateCreator) -> [StoreTemplate] {
        templates.filter { $0.creatorId == creator.id }
    }
    
    /// 依主分類（主題／行程）篩選後的模板
    func filteredTemplates(for mainTab: TemplateStoreMainTab) -> [StoreTemplate] {
        let byMainTab = filterByMainTab(templates, mainTab: mainTab)
        return applyCategoryAndSearchFilters(to: byMainTab)
    }
    
    /// 依主分類篩選的精選模板
    func featuredTemplates(for mainTab: TemplateStoreMainTab) -> [StoreTemplate] {
        let byMainTab = filterByMainTab(featuredTemplates, mainTab: mainTab)
        return applyCountryAndDaysFilters(to: byMainTab)
    }
    
    /// 依主分類篩選的熱門模板（依購買數、評分排序）
    func popularTemplates(for mainTab: TemplateStoreMainTab) -> [StoreTemplate] {
        let byMainTab = filterByMainTab(templates, mainTab: mainTab)
        let filtered = applyCountryAndDaysFilters(to: applySearchOnly(to: byMainTab))
        return filtered.sorted { ($0.purchaseCount, $0.rating ?? 0) > ($1.purchaseCount, $1.rating ?? 0) }
    }
    
    /// 依主分類篩選的最新模板（依建立時間排序）
    func newTemplates(for mainTab: TemplateStoreMainTab) -> [StoreTemplate] {
        let byMainTab = filterByMainTab(templates, mainTab: mainTab)
        let filtered = applyCountryAndDaysFilters(to: applySearchOnly(to: byMainTab))
        return filtered
            .filter { $0.createdAt != nil }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }
    
    private func applySearchOnly(to list: [StoreTemplate]) -> [StoreTemplate] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return list }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return list.filter {
            $0.title.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) } ||
            ($0.authorName?.lowercased().contains(q) ?? false)
        }
    }
    
    private func filterByMainTab(_ list: [StoreTemplate], mainTab: TemplateStoreMainTab) -> [StoreTemplate] {
        switch mainTab {
        case .themes:
            let themeKeywords = ["主題", "主题", "theme"]
            let filtered = list.filter { t in
                t.tags.contains { tag in themeKeywords.contains { tag.contains($0) } } ||
                (t.category?.lowercased() ?? "").contains("theme")
            }
            return filtered.isEmpty ? list : filtered
        case .itineraries:
            let itineraryKeywords = ["行程", "旅行", "trip", "travel", "遊", "游"]
            let filtered = list.filter { t in
                t.tags.contains { tag in itineraryKeywords.contains { tag.contains($0) } } ||
                t.title.contains("遊") || t.title.contains("游") || t.title.contains("之旅") ||
                (t.category?.lowercased() ?? "").contains("japan") ||
                (t.category?.lowercased() ?? "").contains("taiwan") ||
                (t.category?.lowercased() ?? "").contains("korea") ||
                (t.category?.lowercased() ?? "").contains("europe")
            }
            return filtered.isEmpty ? list : filtered
        }
    }
    
    private func applyCategoryAndSearchFilters(to list: [StoreTemplate]) -> [StoreTemplate] {
        var result = list
        switch selectedCategory {
        case .all: break
        case .popular:
            result = result.sorted { ($0.purchaseCount, $0.rating ?? 0) > ($1.purchaseCount, $1.rating ?? 0) }
        case .newArrivals:
            result = result
                .filter { $0.createdAt != nil }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .creators: break
        case .themes:
            let themeKeywords = ["主題", "主题", "theme"]
            let themeFiltered = result.filter { t in
                t.tags.contains { tag in themeKeywords.contains { tag.contains($0) } } ||
                (t.category?.lowercased() ?? "").contains("theme")
            }
            result = themeFiltered.isEmpty ? result : themeFiltered
        case .japan, .taiwan, .korea, .europe:
            if let tag = selectedCategory.displayTag {
                result = result.filter { $0.tags.contains(tag) || $0.title.contains(tag) }
            }
        }
        result = applyCountryAndDaysFilters(to: result)
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                $0.tags.contains { $0.lowercased().contains(q) } ||
                ($0.authorName?.lowercased().contains(q) ?? false) ||
                ($0.country?.lowercased().contains(q) ?? false) ||
                ($0.city?.lowercased().contains(q) ?? false)
            }
        }
        return result
    }

    private func applyCountryAndDaysFilters(to list: [StoreTemplate]) -> [StoreTemplate] {
        var result = list
        if selectedCountry != .all {
            let countryName = countryNameForFilter(selectedCountry)
            result = result.filter { ($0.country ?? "").contains(countryName) }
        }
        switch selectedDays {
        case .all: break
        case .oneToTwo:
            result = result.filter { $0.daysCount >= 1 && $0.daysCount <= 2 }
        case .threeToFour:
            result = result.filter { $0.daysCount >= 3 && $0.daysCount <= 4 }
        case .fivePlus:
            result = result.filter { $0.daysCount >= 5 }
        }
        return result
    }

    private func countryNameForFilter(_ filter: TemplateCountryFilter) -> String {
        switch filter {
        case .all: return ""
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
    
    private func applyFilters() {
        var result = templates
        
        // 依分類篩選
        switch selectedCategory {
        case .all:
            break
        case .popular:
            result = result.sorted { ($0.purchaseCount, $0.rating ?? 0) > ($1.purchaseCount, $1.rating ?? 0) }
        case .newArrivals:
            result = result
                .filter { $0.createdAt != nil }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .creators:
            break
        case .themes:
            let themeKeywords = ["主題", "主题", "theme"]
            let themeFiltered = result.filter { t in
                let hasThemeTag = t.tags.contains { tag in
                    themeKeywords.contains { tag.contains($0) }
                }
                let hasThemeCategory = (t.category?.lowercased() ?? "").contains("theme")
                return hasThemeTag || hasThemeCategory
            }
            result = themeFiltered.isEmpty ? result : themeFiltered
        case .japan, .taiwan, .korea, .europe:
            if let tag = selectedCategory.displayTag {
                result = result.filter { $0.tags.contains(tag) || $0.title.contains(tag) }
            }
        }
        
        result = applyCountryAndDaysFilters(to: result)
        
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                $0.tags.contains { $0.lowercased().contains(q) } ||
                ($0.authorName?.lowercased().contains(q) ?? false) ||
                ($0.country?.lowercased().contains(q) ?? false) ||
                ($0.city?.lowercased().contains(q) ?? false)
            }
        }
        
        filteredTemplates = result
    }
    
    /// 創作者 mock 資料
    private static func mockCreators() -> [TemplateCreator] {
        [
            TemplateCreator(
                id: "secalender",
                name: "Secalender",
                bio: "官方精選行程，帶你探索世界每個角落",
                followerCount: 15800,
                templateCount: 4
            ),
            TemplateCreator(
                id: "travel_lover",
                name: "旅遊達人小美",
                bio: "熱愛分享亞洲自由行，韓台日深度遊",
                followerCount: 3200,
                templateCount: 2
            ),
            TemplateCreator(
                id: "japan_expert",
                name: "日本通阿明",
                bio: "日本各地秘境與經典路線，十年駐日經驗",
                followerCount: 5600,
                templateCount: 2
            ),
        ]
    }
}
