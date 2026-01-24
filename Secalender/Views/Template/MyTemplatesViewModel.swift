

//
//  MyTemplatesViewModel.swift
//  Secalender
//
//  Created by 林平 on 2026/1/22.
//

import Foundation
import SwiftUI

@MainActor
final class MyTemplatesViewModel: ObservableObject {
    @Published var savedTemplates: [SavedTripTemplate] = []
    @Published var isLoading: Bool = false
    @Published var hasLoadedOnce: Bool = false
    
    // 缓存的过滤结果，避免每次 body 计算都重新过滤和排序
    @Published var filteredTemplates: [SavedTripTemplate] = []
    
    // 过滤条件（使用字符串标识符，避免 ViewModel 依赖 View 中的枚举）
    var searchText: String = "" {
        didSet {
            updateFilteredTemplates()
        }
    }
    
    var selectedFilterRawValue: String = TemplateFilterType.myCreations.rawValue {
        didSet {
            updateFilteredTemplates()
        }
    }

    func load(userId: String) { //修改内容：首次載入（只跑一次）
        guard !userId.isEmpty else { return }
        guard !isLoading else { return }
        guard !hasLoadedOnce else { return }

        isLoading = true
        hasLoadedOnce = true

        //修改内容：本地讀取不需要 async/await，避免 Debug 被斷點卡住
        let templates = TripTemplateManager.shared.loadTemplates(for: userId)

        savedTemplates = templates
        updateFilteredTemplates()
        isLoading = false
    }

    func reload(userId: String) { //修改内容：需要時強制重載
        guard !userId.isEmpty else { return }
        guard !isLoading else { return }

        isLoading = true
        let templates = TripTemplateManager.shared.loadTemplates(for: userId)
        savedTemplates = templates
        updateFilteredTemplates()
        isLoading = false
    }
    
    // 更新过滤结果（当搜索文本或筛选条件改变时调用）
    func updateFilteredTemplates() {
        var templates = savedTemplates

        // 使用 rawValue 进行比较，避免直接依赖 TemplateFilterType 枚举
        let filterType = TemplateFilterType(rawValue: selectedFilterRawValue) ?? .myCreations
        switch filterType {
        case .myCreations:
            break
        case .purchased:
            templates = []
        case .friendShares:
            templates = []
        }

        if !searchText.isEmpty {
            templates = templates.filter { t in
                t.title.localizedCaseInsensitiveContains(searchText) ||
                (t.destination?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (t.notes?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                t.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        templates.sort { $0.savedDate > $1.savedDate }
        filteredTemplates = templates
    }
}
