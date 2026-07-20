//
//  AIConfig.swift
//  Secalender
//
//  AI功能配置开关
//

import Foundation
import FirebaseFunctions

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
    // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
    private let defaultOpenAIEnabled = true  // ⚠️ 测试时改为 `false` 以禁用 OpenAI API
    // ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️ ⚠️
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


// MARK: - AI Proxy Client（P0-2）
// 修改内容：所有 OpenAI 呼叫改經 Cloud Functions `aiProxy`，API Key 僅存於後端 Secret，
// 不再打包進 App bundle。部署：firebase functions:secrets:set OPENAI_API_KEY

enum AIProxyError: LocalizedError {
    case emptyResponse
    case rateLimited(String)

    var errorDescription: String? {
        switch self {
        case .emptyResponse: return "AI 回應為空，請稍後再試"
        case .rateLimited(let m): return "AI 服務忙碌中，請稍後再試（\(m)）"
        }
    }
}

final class AIProxyClient {
    static let shared = AIProxyClient()
    private init() {}

    /// 呼叫後端 aiProxy callable，回傳模型文字內容
    /// - Parameters:
    ///   - jsonMode: true 時後端帶 response_format: json_object（prompt 需含 "JSON" 字樣）
    func chat(
        model: String,
        messages: [[String: String]],
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        jsonMode: Bool = false,
        timeout: TimeInterval = 120
    ) async throws -> String {
        let callable = Functions.functions(region: "asia-east1").httpsCallable("aiProxy")
        callable.timeoutInterval = timeout

        let payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "maxTokens": maxTokens,
            "jsonMode": jsonMode
        ]

        do {
            let result = try await callable.call(payload)
            guard let dict = result.data as? [String: Any],
                  let content = dict["content"] as? String,
                  !content.isEmpty else {
                throw AIProxyError.emptyResponse
            }
            return content
        } catch let error as NSError {
            if error.domain == FunctionsErrorDomain,
               let code = FunctionsErrorCode(rawValue: error.code),
               code == .resourceExhausted {
                throw AIProxyError.rateLimited(error.localizedDescription)
            }
            throw error
        }
    }
}
