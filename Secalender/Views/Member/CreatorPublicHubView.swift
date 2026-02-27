//
//  CreatorPublicHubView.swift
//  Secalender
//
//  公開作品集：公開活動、主題、行程、模板 Tab
//  統一卡片格式：封面、標題、標籤、數據、可見性、按鈕
//

import SwiftUI

enum CreatorPublicTab: String, CaseIterable {
    case events = "creator_hub.events"
    case topics = "creator_hub.topics"
    case itineraries = "creator_hub.itineraries"
    case templates = "creator_hub.templates"
}

/// 統一作品卡片格式：封面、標題、標籤、數據、可見性、按鈕
struct CreatorPublicContentCard: View {
    let title: String
    let coverImage: String?
    let tags: [String]
    let stats: (favorites: Int, uses: Int, downloads: Int)
    let visibility: String
    let isOwn: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 封面（可無）
            if let cover = coverImage, !cover.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: cover)
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // 核心標籤
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            // 數據
            HStack(spacing: 12) {
                statItem(icon: "heart.fill", value: stats.favorites)
                statItem(icon: "person.2.fill", value: stats.uses)
                statItem(icon: "arrow.down.circle", value: stats.downloads)
            }
            
            HStack {
                Text(visibility)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if isOwn {
                    Button(action: {}) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func statItem(icon: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct CreatorPublicHubView: View {
    @State private var selectedTab: CreatorPublicTab = .events
    
    // 模擬：是否有公開內容（後續接後端）
    private var hasSampleContent: Bool {
        switch selectedTab {
        case .events: return false
        case .topics: return true
        case .itineraries: return false
        case .templates: return true
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("creator_hub.title".localized())
                .font(.headline)
                .foregroundColor(.primary)
            
            // Tab 選擇
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CreatorPublicTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            Text(tab.rawValue.localized())
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedTab == tab ? Color.blue.opacity(0.12) : Color.clear)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // 內容區：有樣本時顯示卡片，否則顯示空狀態
            if hasSampleContent {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CreatorPublicContentCard(
                            title: "東京美食之旅",
                            coverImage: "fork.knife",
                            tags: ["東京", "3天", "美食"],
                            stats: (12, 28, 5),
                            visibility: "creator_hub.visibility.public".localized(),
                            isOwn: true
                        )
                        .frame(width: 180)
                        
                        CreatorPublicContentCard(
                            title: "週末京都深度遊",
                            coverImage: "map.fill",
                            tags: ["京都", "2天", "文化"],
                            stats: (8, 15, 3),
                            visibility: "creator_hub.visibility.public".localized(),
                            isOwn: true
                        )
                        .frame(width: 180)
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 220)
            } else {
                CreatorPublicContentPlaceholder(tab: selectedTab)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

struct CreatorPublicContentPlaceholder: View {
    let tab: CreatorPublicTab
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tabIcon)
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text("creator_hub.empty_hint".localized(with: tab.rawValue.localized()))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var tabIcon: String {
        switch tab {
        case .events: return "calendar"
        case .topics: return "tag"
        case .itineraries: return "map"
        case .templates: return "doc.text"
        }
    }
}

#Preview {
    CreatorPublicHubView()
        .padding()
}
