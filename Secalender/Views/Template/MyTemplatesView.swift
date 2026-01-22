//
//  MyTemplatesView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  行程模板页面
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MyTemplatesView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    
    @State private var savedTemplates: [SavedTripTemplate] = []
    @State private var searchText: String = ""
    @State private var selectedTag: String? = nil
    @State private var showOnlyFavorites: Bool = false
    @State private var sortOption: TemplateSortOption = .dateDescending
    
    var body: some View {
        List {
            if savedTemplates.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("还没有保存的行程模板")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredAndSortedTemplates) { template in
                    templateRowView(template)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80) // 为TabBar预留空间
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !savedTemplates.isEmpty {
                    Menu {
                        Button(role: .destructive, action: {
                            clearAllTemplates()
                        }) {
                            Label("清除全部", systemImage: "trash")
                        }
                        
                        Divider()
                        
                        Picker("排序方式", selection: $sortOption) {
                            ForEach(TemplateSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            searchAndFilterBar
        }
        .onAppear {
            loadSavedTemplates()
        }
    }
    
    // 搜索和筛选栏
    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索模板...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // 筛选标签和收藏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 收藏筛选
                    Button(action: {
                        showOnlyFavorites.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                            Text("收藏")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showOnlyFavorites ? Color.orange.opacity(0.2) : Color(UIColor.systemGray6))
                        .foregroundColor(showOnlyFavorites ? .orange : .secondary)
                        .cornerRadius(16)
                    }
                    
                    // 标签筛选
                    ForEach(getAllTags(), id: \.self) { tag in
                        Button(action: {
                            selectedTag = selectedTag == tag ? nil : tag
                        }) {
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedTag == tag ? Color.blue.opacity(0.2) : Color(UIColor.systemGray6))
                                .foregroundColor(selectedTag == tag ? .blue : .secondary)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    // 模板行视图
    private func templateRowView(_ template: SavedTripTemplate) -> some View {
        NavigationLink(destination: PlanDetailView(
            plan: template.plan,
            onEdit: { planToEdit in
                updateTemplate(template.id, with: planToEdit)
            },
            onAddToCalendar: {
                // 标记为已使用
                TripTemplateManager.shared.markTemplateAsUsed(template.id, for: userManager.userOpenId)
                savePlanToCalendar(template.plan)
                loadSavedTemplates()
            },
            onSaveToTemplate: { _ in }
        )
        .environmentObject(userManager)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(template.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if template.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // 目的地和天数
                HStack(spacing: 12) {
                    if let destination = template.destination {
                        Label(destination, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Label("\(template.plan.days.count)天", systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if template.usageCount > 0 {
                        Label("\(template.usageCount)次", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 标签
                if !template.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(template.tags.prefix(5), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                // 备注预览
                if let notes = template.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // 日期信息
                HStack {
                    Text("保存于 \(formatDate(template.savedDate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let lastUsed = template.lastUsedDate {
                        Text("最后使用 \(formatDate(lastUsed))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: {
                TripTemplateManager.shared.toggleTemplateFavorite(template.id, for: userManager.userOpenId)
                loadSavedTemplates()
            }) {
                Label(template.isFavorite ? "取消收藏" : "收藏", systemImage: template.isFavorite ? "heart.slash" : "heart")
            }
            .tint(.orange)
            
            Button(role: .destructive, action: {
                deleteTemplate(template.id)
            }) {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // 筛选和排序后的模板
    private var filteredAndSortedTemplates: [SavedTripTemplate] {
        var templates = savedTemplates
        
        // 搜索筛选
        if !searchText.isEmpty {
            templates = templates.filter { template in
                template.title.localizedCaseInsensitiveContains(searchText) ||
                template.destination?.localizedCaseInsensitiveContains(searchText) ?? false ||
                template.notes?.localizedCaseInsensitiveContains(searchText) ?? false ||
                template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // 收藏筛选
        if showOnlyFavorites {
            templates = templates.filter { $0.isFavorite }
        }
        
        // 标签筛选
        if let selectedTag = selectedTag {
            templates = templates.filter { $0.tags.contains(selectedTag) }
        }
        
        // 排序
        switch sortOption {
        case .dateDescending:
            templates.sort { $0.savedDate > $1.savedDate }
        case .dateAscending:
            templates.sort { $0.savedDate < $1.savedDate }
        case .usageCount:
            templates.sort { $0.usageCount > $1.usageCount }
        case .title:
            templates.sort { $0.title < $1.title }
        }
        
        return templates
    }
    
    // 获取所有标签
    private func getAllTags() -> [String] {
        let allTags = Set(savedTemplates.flatMap { $0.tags })
        return Array(allTags).sorted()
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - 行程模板管理
    
    /// 加载保存的行程模板
    private func loadSavedTemplates() {
        let userId = userManager.userOpenId
        savedTemplates = TripTemplateManager.shared.loadTemplates(for: userId)
    }
    
    /// 保存行程到日历（从PlanResult）
    private func savePlanToCalendar(_ plan: PlanResult) {
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            
            let items = PlanGenerator.shared.convertToScheduleItems(plan)
            
            for item in items {
                let startDate = combine(date: item.date, time: item.startTime)
                let endDate = combine(date: item.date, time: item.endTime)
                
                let dateString = dateFormatter.string(from: item.date)
                let startString = timeFormatter.string(from: startDate)
                let endString = timeFormatter.string(from: endDate)
                
                var event = Event()
                event.title = item.title
                event.creatorOpenid = userManager.userOpenId
                event.color = "#4285F4"
                event.date = dateString
                event.startTime = startString
                event.endTime = endString
                event.endDate = dateString
                event.destination = item.location
                event.mapObj = ""
                event.openChecked = 0
                event.personChecked = 0
                event.createTime = ""
                event.information = item.description
                event.groupId = nil
                
                do {
                    try await EventManager.shared.addEvent(event: event)
                } catch {
                    print("添加事件失敗：\(error)")
                }
            }
        }
    }
    
    /// 組合日期與時間，回傳帶時間的 Date
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: calendar.component(.second, from: time),
            of: date
        ) ?? date
    }
    
    /// 更新模板
    private func updateTemplate(_ templateId: UUID, with plan: PlanResult) {
        let userId = userManager.userOpenId
        var templates = TripTemplateManager.shared.loadTemplates(for: userId)
        
        if let index = templates.firstIndex(where: { $0.id == templateId }) {
            templates[index].plan = plan
            TripTemplateManager.shared.updateTemplate(templates[index], for: userId)
            loadSavedTemplates()
        }
    }
    
    /// 删除模板
    private func deleteTemplate(_ templateId: UUID) {
        let userId = userManager.userOpenId
        TripTemplateManager.shared.deleteTemplate(templateId, for: userId)
        loadSavedTemplates()
    }
    
    /// 清除所有模板
    private func clearAllTemplates() {
        let userId = userManager.userOpenId
        TripTemplateManager.shared.clearAllTemplates(for: userId)
        savedTemplates.removeAll()
    }
}
