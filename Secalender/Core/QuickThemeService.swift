//
//  QuickThemeService.swift
//  Secalender
//
//  修改内容：Step4 — 自訂主題上 Firestore
//  路徑：users/{userId}/quick_themes/{themeId}（整份 QuickTheme JSON），與 theme_prompts 並存。
//  UserDefaults 仍為本地快取；雲端為跨裝置真實來源（remote wins）。
//  另提供 shared_quick_themes/{themeId} 公開分享，供模板市集後續接入。
//

import Foundation
import FirebaseFirestore

final class QuickThemeService {
    static let shared = QuickThemeService()
    private let db = Firestore.firestore()
    private let collectionName = "quick_themes"
    private let sharedCollectionName = "shared_quick_themes"

    private init() {}

    private func userCollection(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection(collectionName)
    }

    // MARK: - Upsert / Delete（單筆同步）

    func upsert(theme: QuickTheme, userId: String) async {
        guard !userId.isEmpty, !theme.isBuiltIn else { return }
        do {
            let data = try JSONEncoder().encode(theme)
            guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            dict["updatedAt"] = FieldValue.serverTimestamp()
            try await userCollection(userId).document(theme.id.uuidString).setData(dict)
            print("✅ [QuickThemeService] 已同步主題: \(theme.key)")
        } catch {
            print("⚠️ [QuickThemeService] 同步失敗: \(error.localizedDescription)")
        }
    }

    func delete(themeId: UUID, userId: String) async {
        guard !userId.isEmpty else { return }
        do {
            try await userCollection(userId).document(themeId.uuidString).delete()
            print("✅ [QuickThemeService] 已刪除雲端主題: \(themeId)")
        } catch {
            print("⚠️ [QuickThemeService] 刪除失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch（跨裝置拉取）

    func fetchAll(userId: String) async -> [QuickTheme] {
        guard !userId.isEmpty else { return [] }
        do {
            let snapshot = try await userCollection(userId).getDocuments()
            return snapshot.documents.compactMap { doc in
                var dict = doc.data()
                dict.removeValue(forKey: "updatedAt")  // Timestamp 非 JSON 可序列化
                guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                return try? JSONDecoder().decode(QuickTheme.self, from: data)
            }
        } catch {
            print("⚠️ [QuickThemeService] 拉取失敗: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - 公開分享（模板市集接入點）

    /// 發佈主題到公開集合；回傳是否成功。市集可依 creatorId / themeKey 列出。
    func publishShared(theme: QuickTheme, creatorId: String, creatorName: String?) async -> Bool {
        guard !creatorId.isEmpty, !theme.isBuiltIn else { return false }
        do {
            let data = try JSONEncoder().encode(theme)
            guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            dict["creatorId"] = creatorId
            dict["creatorName"] = creatorName ?? ""
            dict["publishedAt"] = FieldValue.serverTimestamp()
            try await db.collection(sharedCollectionName).document(theme.id.uuidString).setData(dict)
            return true
        } catch {
            print("⚠️ [QuickThemeService] 發佈失敗: \(error.localizedDescription)")
            return false
        }
    }
}
