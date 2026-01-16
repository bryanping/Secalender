//
//  AIConfig.swift
//  Secalender
//
//  AI功能配置开关
//

import Foundation

/// AI功能配置管理器
final class AIConfig {
    static let shared = AIConfig()
    private init() {}
    
    // MARK: - OpenAI API 开关
    
    /// OpenAI API 使用开关（代码级别）
    /// - `true`: 启用 OpenAI API，使用AI生成高质量行程
    /// - `false`: 禁用 OpenAI API，使用基础生成器（节省流量和成本）
    ///
    /// 设置方式：
    /// 1. 直接修改这里（需要重新编译）
    /// 2. 使用 UserDefaults（运行时修改）
    var isOpenAIEnabled: Bool {
        get {
            // 优先从 UserDefaults 读取（允许运行时切换）
            if let userDefaultValue = UserDefaults.standard.object(forKey: "AIConfig_OpenAIEnabled") as? Bool {
                return userDefaultValue
            }
            // 默认值（代码级别开关）
            return defaultOpenAIEnabled
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AIConfig_OpenAIEnabled")
            print("🔧 [AIConfig] OpenAI API 开关已更新: \(newValue ? "启用" : "禁用")")
        }
    }
    
    /// 代码级别的默认开关值（修改这里后需要重新编译）
    /// 设置为 `false` 可以永久禁用 OpenAI API，避免测试时产生费用
    private let defaultOpenAIEnabled = true  // ⚠️ 测试时改为 false
    
    // MARK: - 调试信息
    
    /// 显示当前配置状态
    func printConfig() {
        print("""
        📊 [AIConfig] AI 配置状态：
        - OpenAI API: \(isOpenAIEnabled ? "✅ 启用" : "❌ 禁用")
        - 默认值: \(defaultOpenAIEnabled ? "启用" : "禁用")
        """)
    }
    
    /// 重置为默认值
    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: "AIConfig_OpenAIEnabled")
        print("🔧 [AIConfig] 已重置为默认值: \(defaultOpenAIEnabled ? "启用" : "禁用")")
    }
}
