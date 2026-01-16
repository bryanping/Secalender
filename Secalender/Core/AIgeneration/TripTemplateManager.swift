//
//  TripTemplateManager.swift
//  Secalender
//
//  行程模板管理器（保存和管理行程建议）
//

import Foundation

/// 保存的行程模板
struct SavedTripTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var plan: PlanResult
    var savedDate: Date
    var lastUsedDate: Date?  // 最后使用日期
    var tags: [String]
    var notes: String?        // 备注/描述
    var usageCount: Int       // 使用次数
    var isFavorite: Bool      // 是否收藏
    var destination: String?  // 目的地（快速访问）
    
    init(
        id: UUID = UUID(),
        title: String,
        plan: PlanResult,
        savedDate: Date = Date(),
        lastUsedDate: Date? = nil,
        tags: [String] = [],
        notes: String? = nil,
        usageCount: Int = 0,
        isFavorite: Bool = false,
        destination: String? = nil
    ) {
        self.id = id
        self.title = title
        self.plan = plan
        self.savedDate = savedDate
        self.lastUsedDate = lastUsedDate
        self.tags = tags
        self.notes = notes
        self.usageCount = usageCount
        self.isFavorite = isFavorite
        
        // 自动提取目的地
        if let dest = destination {
            self.destination = dest
        } else {
            // 从 plan 中提取目的地
            self.destination = SavedTripTemplate.extractDestination(from: plan)
        }
    }
    
    /// 从 PlanResult 中提取目的地（静态方法）
    static func extractDestination(from plan: PlanResult) -> String? {
        guard let firstDay = plan.days.first,
              let firstActivity = firstDay.blocks.first(where: { $0.type == .activity }) else {
            return nil
        }
        return firstActivity.location
    }
    
    /// 更新使用记录
    mutating func markAsUsed() {
        usageCount += 1
        lastUsedDate = Date()
    }
    
    /// 切换收藏状态
    mutating func toggleFavorite() {
        isFavorite.toggle()
    }
    
    /// 更新标题
    mutating func updateTitle(_ newTitle: String) {
        title = newTitle
    }
    
    /// 更新标签
    mutating func updateTags(_ newTags: [String]) {
        tags = newTags
    }
    
    /// 更新备注
    mutating func updateNotes(_ newNotes: String?) {
        notes = newNotes
    }
    
    static func == (lhs: SavedTripTemplate, rhs: SavedTripTemplate) -> Bool {
        return lhs.id == rhs.id
    }
}

/// 行程模板管理器
final class TripTemplateManager {
    static let shared = TripTemplateManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let templatesKey = "saved_trip_templates"
    
    /// 保存行程模板
    func saveTemplate(_ template: SavedTripTemplate, for userId: String) {
        var templates = loadTemplates(for: userId)
        
        // 检查是否已存在相同ID的模板（避免重复保存）
        if templates.contains(where: { $0.id == template.id }) {
            print("⚠️ 模板已存在，跳过重复保存: \(template.title)")
            return
        }
        
        templates.append(template)
        
        // 保存模板列表
        saveTemplates(templates, for: userId)
        print("✅ 行程模板已保存: \(template.title) (共 \(templates.count) 个模板)")
    }
    
    /// 加载所有行程模板
    func loadTemplates(for userId: String) -> [SavedTripTemplate] {
        let key = "\(templatesKey)_\(userId)"
        
        guard let data = userDefaults.data(forKey: key) else {
            print("📭 本地行程模板为空")
            return []
        }
        
        // 配置解码器以正确处理 Date
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let templates = try? decoder.decode([SavedTripTemplate].self, from: data) else {
            print("❌ 解析行程模板失败")
            return []
        }
        
        print("✅ 从本地加载了 \(templates.count) 个行程模板")
        return templates
    }
    
    /// 删除行程模板
    func deleteTemplate(_ templateId: UUID, for userId: String) {
        var templates = loadTemplates(for: userId)
        templates.removeAll { $0.id == templateId }
        
        let key = "\(templatesKey)_\(userId)"
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let encoded = try? encoder.encode(templates) {
            userDefaults.set(encoded, forKey: key)
            print("🗑️ 已删除行程模板")
        }
    }
    
    /// 清除所有行程模板
    func clearAllTemplates(for userId: String) {
        let key = "\(templatesKey)_\(userId)"
        userDefaults.removeObject(forKey: key)
        print("🗑️ 已清除所有行程模板")
    }
    
    /// 更新模板（用于编辑标题、标签、备注等）
    func updateTemplate(_ template: SavedTripTemplate, for userId: String) {
        var templates = loadTemplates(for: userId)
        
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates(templates, for: userId)
            print("✅ 行程模板已更新: \(template.title)")
        }
    }
    
    /// 标记模板为已使用
    func markTemplateAsUsed(_ templateId: UUID, for userId: String) {
        var templates = loadTemplates(for: userId)
        
        if let index = templates.firstIndex(where: { $0.id == templateId }) {
            templates[index].markAsUsed()
            saveTemplates(templates, for: userId)
        }
    }
    
    /// 切换模板收藏状态
    func toggleTemplateFavorite(_ templateId: UUID, for userId: String) {
        var templates = loadTemplates(for: userId)
        
        if let index = templates.firstIndex(where: { $0.id == templateId }) {
            templates[index].toggleFavorite()
            saveTemplates(templates, for: userId)
        }
    }
    
    /// 搜索模板（按标题和标签）
    func searchTemplates(_ query: String, for userId: String) -> [SavedTripTemplate] {
        let allTemplates = loadTemplates(for: userId)
        
        guard !query.isEmpty else {
            return allTemplates
        }
        
        let lowercasedQuery = query.lowercased()
        return allTemplates.filter { template in
            template.title.lowercased().contains(lowercasedQuery) ||
            template.destination?.lowercased().contains(lowercasedQuery) == true ||
            template.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) }) ||
            template.notes?.lowercased().contains(lowercasedQuery) == true
        }
    }
    
    /// 按标签筛选模板
    func filterTemplates(byTag tag: String, for userId: String) -> [SavedTripTemplate] {
        let allTemplates = loadTemplates(for: userId)
        return allTemplates.filter { $0.tags.contains(tag) }
    }
    
    /// 获取所有标签
    func getAllTags(for userId: String) -> [String] {
        let allTemplates = loadTemplates(for: userId)
        let allTags = allTemplates.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    /// 按收藏状态筛选
    func getFavoriteTemplates(for userId: String) -> [SavedTripTemplate] {
        return loadTemplates(for: userId).filter { $0.isFavorite }
    }
    
    // MARK: - 私有方法
    
    /// 保存模板列表（内部方法）
    private func saveTemplates(_ templates: [SavedTripTemplate], for userId: String) {
        let key = "\(templatesKey)_\(userId)"
        
        // 配置编码器以正确处理 Date
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // 将模板转换为可编码的数据
        do {
            let encoded = try encoder.encode(templates)
            userDefaults.set(encoded, forKey: key)
            userDefaults.synchronize() // 确保立即写入磁盘
            print("✅ 模板列表已保存到本地: \(templates.count) 个模板")
        } catch {
            print("❌ 保存模板列表失败: \(error.localizedDescription)")
            // 输出更详细的错误信息
            if let encodingError = error as? EncodingError {
                print("   编码错误详情: \(encodingError)")
            }
        }
    }
}
