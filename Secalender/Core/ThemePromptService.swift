//
//  ThemePromptService.swift
//  Secalender
//
//  主題專屬提示詞 Firebase 同步：存儲與讀取，避免主題生成偏題（如寵物餵養→天安門旅遊）
//

import Foundation
import FirebaseFirestore

/// 主題專屬提示詞 Firebase 服務
/// 存儲路徑：users/{userId}/theme_prompts/{themeKey}
final class ThemePromptService {
    static let shared = ThemePromptService()
    private let db = Firestore.firestore()
    private let collectionName = "theme_prompts"
    
    private init() {}
    
    /// 儲存主題提示詞到 Firebase
    func savePrompt(themeKey: String, promptPrefix: String, userId: String) async {
        guard !userId.isEmpty, !themeKey.isEmpty else { return }
        let ref = db.collection("users").document(userId).collection(collectionName).document(themeKey)
        do {
            try await ref.setData([
                "promptPrefix": promptPrefix,
                "themeKey": themeKey,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ [ThemePromptService] 已儲存主題提示詞: \(themeKey)")
        } catch {
            print("⚠️ [ThemePromptService] 儲存失敗: \(error.localizedDescription)")
        }
    }
    
    /// 從 Firebase 讀取主題提示詞
    func fetchPrompt(themeKey: String, userId: String) async -> String? {
        guard !userId.isEmpty, !themeKey.isEmpty else { return nil }
        let ref = db.collection("users").document(userId).collection(collectionName).document(themeKey)
        do {
            let doc = try await ref.getDocument()
            return doc.data()?["promptPrefix"] as? String
        } catch {
            print("⚠️ [ThemePromptService] 讀取失敗: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 刪除主題提示詞
    func deletePrompt(themeKey: String, userId: String) async {
        guard !userId.isEmpty, !themeKey.isEmpty else { return }
        let ref = db.collection("users").document(userId).collection(collectionName).document(themeKey)
        do {
            try await ref.delete()
            print("✅ [ThemePromptService] 已刪除主題提示詞: \(themeKey)")
        } catch {
            print("⚠️ [ThemePromptService] 刪除失敗: \(error.localizedDescription)")
        }
    }
}
