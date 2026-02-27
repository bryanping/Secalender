//
//  TemplatePurchaseManager.swift
//  Secalender
//
//  模板購買紀錄管理：追蹤用戶已購買的市集模板，支援多設備同步預留
//

import Foundation

/// 模板購買紀錄管理器
final class TemplatePurchaseManager {
    static let shared = TemplatePurchaseManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private func key(for userId: String) -> String { "purchased_store_templates_\(userId)" }
    
    /// 標記模板為已購買
    func markAsPurchased(templateId: String, for userId: String) {
        var ids = loadPurchasedIds(for: userId)
        if !ids.contains(templateId) {
            ids.append(templateId)
            savePurchasedIds(ids, for: userId)
        }
    }
    
    /// 檢查是否已購買
    func isPurchased(templateId: String, for userId: String) -> Bool {
        loadPurchasedIds(for: userId).contains(templateId)
    }
    
    /// 取得已購買的模板 ID 列表（供 MyTemplatesView 篩選等用）
    func purchasedTemplateIds(for userId: String) -> [String] {
        loadPurchasedIds(for: userId)
    }
    
    private func loadPurchasedIds(for userId: String) -> [String] {
        userDefaults.stringArray(forKey: key(for: userId)) ?? []
    }
    
    private func savePurchasedIds(_ ids: [String], for userId: String) {
        userDefaults.set(ids, forKey: key(for: userId))
    }
}
