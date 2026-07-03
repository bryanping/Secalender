//
//  ChatMessageManager.swift
//  Secalender
//
//  对话消息模型和管理器（整合版）
//

import Foundation

// MARK: - 消息角色

/// 消息角色
enum MessageRole {
    case user      // 用户
    case assistant // AI助手
    case system    // 系统消息
}

// MARK: - 对话消息

/// 对话消息
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    var planResult: PlanResult? = nil  // 如果消息包含生成的行程
    
    init(role: MessageRole, content: String, planResult: PlanResult? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.planResult = planResult
    }
    
    // 用于从本地存储恢复
    init(id: UUID, role: MessageRole, content: String, timestamp: Date, planResult: PlanResult? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.planResult = planResult
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 聊天记录管理器

/// 聊天记录管理器（本地保存和内存管理）
final class ChatMessageManager {
    static let shared = ChatMessageManager()
    private init() {}
    
    // MARK: - 本地存储相关
    
    private let userDefaults = UserDefaults.standard
    private let chatHistoryKey = "chat_history"
    
    // MARK: - 内存管理（可选，用于运行时管理）
    
    private var inMemoryMessages: [ChatMessage] = []
    
    // MARK: - 本地存储方法
    
    /// 保存聊天记录到本地
    func saveChatHistory(_ messages: [ChatMessage], for userId: String) {
        let key = "\(chatHistoryKey)_\(userId)"
        
        // 将 ChatMessage 转换为可编码的字典
        let messagesData = messages.map { message in
            [
                "id": message.id.uuidString,
                "role": roleToString(message.role),
                "content": message.content,
                "timestamp": message.timestamp.timeIntervalSince1970,
                "hasPlan": message.planResult != nil
            ]
        }
        
        userDefaults.set(messagesData, forKey: key)
        print("✅ 聊天记录已保存: \(messages.count) 条消息")
    }
    
    /// 从本地加载聊天记录
    func loadChatHistory(for userId: String) -> [ChatMessage] {
        let key = "\(chatHistoryKey)_\(userId)"
        
        guard let messagesData = userDefaults.array(forKey: key) as? [[String: Any]] else {
            print("📭 本地聊天记录为空")
            return []
        }
        
        var messages: [ChatMessage] = []
        for data in messagesData {
            guard
                let idString = data["id"] as? String,
                let id = UUID(uuidString: idString),
                let roleString = data["role"] as? String,
                let role = stringToRole(roleString),
                let content = data["content"] as? String,
                let timestamp = data["timestamp"] as? TimeInterval
            else {
                continue
            }
            
            let date = Date(timeIntervalSince1970: timestamp)
            let message = ChatMessage(id: id, role: role, content: content, timestamp: date, planResult: nil)
            // 注意：planResult 不会保存（因为 PlanResult 较复杂），需要时重新生成
            messages.append(message)
        }
        
        print("✅ 从本地加载了 \(messages.count) 条聊天记录")
        return messages
    }
    
    /// 清除指定用户的聊天记录
    func clearChatHistory(for userId: String) {
        let key = "\(chatHistoryKey)_\(userId)"
        userDefaults.removeObject(forKey: key)
        print("🗑️ 已清除用户 \(userId) 的聊天记录")
    }
    
    /// 清除所有聊天记录
    func clearAllChatHistory() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix(chatHistoryKey) {
                userDefaults.removeObject(forKey: key)
            }
        }
        print("🗑️ 已清除所有聊天记录")
    }
    
    // MARK: - 内存管理方法（可选使用）
    
    /// 添加消息到内存
    func addMessage(_ message: ChatMessage) {
        inMemoryMessages.append(message)
    }
    
    /// 获取所有内存中的消息
    func getAllMessages() -> [ChatMessage] {
        return inMemoryMessages
    }
    
    /// 获取最近的N条消息（用于上下文）
    func getRecentMessages(_ count: Int = 10) -> [ChatMessage] {
        return Array(inMemoryMessages.suffix(count))
    }
    
    /// 清除内存中的历史
    func clearMemoryHistory() {
        inMemoryMessages.removeAll()
    }
    
    /// 添加系统消息到内存
    func addSystemMessage(_ content: String) {
        inMemoryMessages.append(ChatMessage(role: .system, content: content))
    }
    
    // MARK: - 辅助方法
    
    private func roleToString(_ role: MessageRole) -> String {
        switch role {
        case .user: return "user"
        case .assistant: return "assistant"
        case .system: return "system"
        }
    }
    
    private func stringToRole(_ string: String) -> MessageRole? {
        switch string {
        case "user": return .user
        case "assistant": return .assistant
        case "system": return .system
        default: return nil
        }
    }
}
