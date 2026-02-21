//
//  TemplateStoreViewModel.swift
//  Secalender
//
//  模板市集 ViewModel：資料載入、分類篩選、搜尋、購買狀態
//

import Foundation
import SwiftUI

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
    
    /// 篩選後的模板列表
    @Published var filteredTemplates: [StoreTemplate] = []
    
    /// 創作者列表（用於博主分類）
    @Published var creators: [TemplateCreator] = []
    
    private var userId: String = ""
    
    func load(userId: String) {
        guard !userId.isEmpty else { return }
        self.userId = userId
        isLoading = true
        errorMessage = nil
        
        // 模擬載入延遲（後續改為 API）
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            let all = Self.mockTemplates()
            let creatorList = Self.mockCreators()
            await MainActor.run {
                templates = all
                featuredTemplates = all.filter { $0.isFeatured }
                creators = creatorList
                applyFilters()
                isLoading = false
            }
        }
    }
    
    func refresh(userId: String) {
        load(userId: userId)
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
            // 創作者分類：不篩選模板，由 UI 顯示創作者卡片
            break
        case .japan, .taiwan, .korea, .europe:
            if let tag = selectedCategory.displayTag {
                result = result.filter { $0.tags.contains(tag) || $0.title.contains(tag) }
            }
        }
        
        // 搜尋
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                $0.tags.contains { $0.lowercased().contains(q) } ||
                ($0.authorName?.lowercased().contains(q) ?? false)
            }
        }
        
        filteredTemplates = result
    }
    
    /// 市集 mock 資料（後續改為 API）
    private static func mockTemplates() -> [StoreTemplate] {
        let cal = Calendar.current
        let today = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: today)!
        
        return [
            StoreTemplate(
                title: "東京3日遊",
                description: "經典東京景點，包含淺草寺、東京鐵塔、新宿等。適合第一次造訪東京的旅客。",
                tags: ["東京", "日本", "文化", "購物"],
                price: 299,
                category: "japan",
                rating: 4.8,
                purchaseCount: 1250,
                daysCount: 3,
                authorName: "Secalender",
                creatorId: "secalender",
                isFeatured: true,
                createdAt: weekAgo
            ),
            StoreTemplate(
                title: "京都深度文化之旅",
                description: "探索古都京都的傳統文化與歷史，含祇園、清水寺、金閣寺等經典路線。",
                tags: ["京都", "日本", "文化", "歷史"],
                price: 399,
                category: "japan",
                rating: 4.9,
                purchaseCount: 890,
                daysCount: 4,
                authorName: "Secalender",
                creatorId: "secalender",
                isFeatured: true,
                createdAt: today
            ),
            StoreTemplate(
                title: "大阪美食之旅",
                description: "品嚐大阪道地美食，體驗當地文化，含道頓堀、黑門市場、環球影城。",
                tags: ["大阪", "日本", "美食", "文化"],
                price: 349,
                category: "japan",
                rating: 4.7,
                purchaseCount: 720,
                daysCount: 3,
                authorName: "Secalender",
                creatorId: "secalender",
                isFeatured: false,
                createdAt: today
            ),
            StoreTemplate(
                title: "首爾4日購物美食行",
                description: "弘大、明洞、東大門時尚購物與韓式料理體驗。",
                tags: ["首爾", "韓國", "美食", "購物"],
                price: 279,
                category: "korea",
                rating: 4.6,
                purchaseCount: 560,
                daysCount: 4,
                authorName: "旅遊達人小美",
                creatorId: "travel_lover",
                isFeatured: false,
                createdAt: weekAgo
            ),
            StoreTemplate(
                title: "台北文青3日遊",
                description: "大稻埕、華山、松菸文創園區與在地小吃探索。",
                tags: ["台北", "台灣", "文化", "美食"],
                price: 0,
                category: "taiwan",
                rating: 4.5,
                purchaseCount: 2100,
                daysCount: 3,
                authorName: "Secalender",
                creatorId: "secalender",
                isFeatured: true,
                createdAt: today
            ),
            StoreTemplate(
                title: "花蓮太魯閣2日自然行",
                description: "太魯閣國家公園、清水斷崖、七星潭海景一日遊。",
                tags: ["花蓮", "台灣", "自然", "戶外"],
                price: 199,
                category: "taiwan",
                rating: 4.7,
                purchaseCount: 430,
                daysCount: 2,
                authorName: "旅遊達人小美",
                creatorId: "travel_lover",
                isFeatured: false,
                createdAt: weekAgo
            ),
            StoreTemplate(
                title: "巴黎浪漫5日",
                description: "艾菲爾鐵塔、羅浮宮、聖母院與塞納河畔漫步。",
                tags: ["巴黎", "歐洲", "藝術", "浪漫"],
                price: 499,
                category: "europe",
                rating: 4.9,
                purchaseCount: 380,
                daysCount: 5,
                authorName: "日本通阿明",
                creatorId: "japan_expert",
                isFeatured: true,
                createdAt: weekAgo
            ),
            StoreTemplate(
                title: "沖繩海島4日",
                description: "美麗海水族館、古宇利島、萬座毛與海灘休閒。",
                tags: ["沖繩", "日本", "海島", "潛水"],
                price: 329,
                category: "japan",
                rating: 4.8,
                purchaseCount: 520,
                daysCount: 4,
                authorName: "日本通阿明",
                creatorId: "japan_expert",
                isFeatured: false,
                createdAt: today
            ),
        ]
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
