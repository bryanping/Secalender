//
//  PlanningPreset.swift
//  Secalender
//
//  修改內容：常用安排 — 保存使用者上次「真正套用」的標準化輸入，供再次使用時沿用偏好。
//  - 只保存通用偏好（目的地、興趣、預算、常用出發地、住宿、限制、備註），不保存日期／航班／參與者（每次重新確認）
//  - 按 userId 隔離：UserDefaults key 帶 uid；雲端 users/{uid}/planning_presets/{id}
//  - 帶 version；舊版缺欄位以預設補齊（Codable 全 optional / default），回訪流程不失效
//

import Foundation
import FirebaseFirestore

/// 常用安排的來源流程
enum PlanningPresetKind: String, Codable {
    case travel      // TravelPlannerContent 四步驟
    case themeForm   // AIPlannerView 主題表單
    case freeInput   // AIPlannerView 一句話 / 模型驅動
}

struct PlanningPreset: Identifiable, Codable, Equatable {
    static let currentVersion = 1

    var id: String
    var version: Int
    var name: String
    var kind: PlanningPresetKind
    /// 對應 QuickTheme.key（主題表單 / 主題旅遊時有值）
    var themeKey: String?
    /// 標準化輸入（不含日期等每次變動條件）
    var inputs: [String: String]
    var createdAt: Date
    var lastUsedAt: Date
    var useCount: Int

    init(
        id: String = UUID().uuidString,
        version: Int = PlanningPreset.currentVersion,
        name: String,
        kind: PlanningPresetKind,
        themeKey: String? = nil,
        inputs: [String: String] = [:],
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        useCount: Int = 0
    ) {
        self.id = id
        self.version = version
        self.name = name
        self.kind = kind
        self.themeKey = themeKey
        self.inputs = inputs
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }

    /// 舊版遷移：缺欄位補預設
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "常用安排"
        kind = try c.decodeIfPresent(PlanningPresetKind.self, forKey: .kind) ?? .freeInput
        themeKey = try c.decodeIfPresent(String.self, forKey: .themeKey)
        inputs = try c.decodeIfPresent([String: String].self, forKey: .inputs) ?? [:]
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastUsedAt = try c.decodeIfPresent(Date.self, forKey: .lastUsedAt) ?? createdAt
        useCount = try c.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
    }

    // MARK: - 標準化輸入 key（各流程共用）
    enum Key {
        static let input = "input"                    // 一句話原句
        static let title = "title"
        static let destination = "destination"
        static let country = "country"
        static let city = "city"
        static let interests = "interests"            // 逗號分隔 rawValue
        static let budget = "budget"
        static let departureAddress = "departureAddress"
        static let accommodationAddress = "accommodationAddress"
        static let restrictions = "restrictions"      // 逗號分隔 rawValue
        static let notes = "notes"
        static let formAnswers = "formAnswers"        // JSON（已排除日期題）
    }

    /// 卡片副標：說明會沿用什麼
    var summaryText: String {
        var parts: [String] = []
        if let d = inputs[Key.destination], !d.isEmpty { parts.append(d) }
        if let i = inputs[Key.interests], !i.isEmpty { parts.append(i.replacingOccurrences(of: ",", with: "、")) }
        if let b = inputs[Key.budget], !b.isEmpty { parts.append(b) }
        if parts.isEmpty, let s = inputs[Key.input], !s.isEmpty { parts.append(s) }
        return parts.isEmpty ? "沿用上次偏好，只改日期" : parts.joined(separator: " · ")
    }

    /// 由內容產生預設名稱
    static func defaultName(kind: PlanningPresetKind, inputs: [String: String]) -> String {
        if let d = inputs[Key.destination], !d.isEmpty {
            return kind == .travel ? "\(d) 旅行" : "\(d) 出遊"
        }
        if let t = inputs[Key.title], !t.isEmpty { return t }
        if let s = inputs[Key.input], !s.isEmpty { return String(s.prefix(12)) }
        return "我的常用安排"
    }
}

// MARK: - Store（本地快取 + 雲端）

final class PlanningPresetStore: ObservableObject {
    static let shared = PlanningPresetStore()
    private let db = Firestore.firestore()
    private init() {}

    private func localKey(_ userId: String) -> String { "planning_presets_\(userId)" }

    /// 按使用者載入（未登入回空，不沿用其他帳號）
    func load(userId: String) -> [PlanningPreset] {
        guard !userId.isEmpty,
              let data = UserDefaults.standard.data(forKey: localKey(userId)),
              let list = try? JSONDecoder().decode([PlanningPreset].self, from: data) else { return [] }
        return list.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }

    private func saveLocal(_ list: [PlanningPreset], userId: String) {
        guard !userId.isEmpty, let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: localKey(userId))
        objectWillChange.send()
    }

    func upsert(_ preset: PlanningPreset, userId: String) {
        guard !userId.isEmpty else { return }
        var list = load(userId: userId)
        list.removeAll { $0.id == preset.id }
        list.insert(preset, at: 0)
        if list.count > 20 { list = Array(list.prefix(20)) }
        saveLocal(list, userId: userId)
        Task { await syncUp(preset, userId: userId) }
    }

    func delete(id: String, userId: String) {
        guard !userId.isEmpty else { return }
        var list = load(userId: userId)
        list.removeAll { $0.id == id }
        saveLocal(list, userId: userId)
        Task { try? await collection(userId).document(id).delete() }
    }

    /// 再次使用：更新使用時間與次數
    func markUsed(id: String, userId: String) {
        var list = load(userId: userId)
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        list[i].lastUsedAt = Date()
        list[i].useCount += 1
        saveLocal(list, userId: userId)
        let p = list[i]
        Task { await syncUp(p, userId: userId) }
    }

    private func collection(_ userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("planning_presets")
    }

    private func syncUp(_ preset: PlanningPreset, userId: String) async {
        do {
            let data = try JSONEncoder().encode(preset)
            guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            dict["updatedAt"] = FieldValue.serverTimestamp()
            try await collection(userId).document(preset.id).setData(dict, merge: true)
        } catch {
            print("⚠️ [PlanningPresetStore] 同步失敗: \(error.localizedDescription)")
        }
    }

    /// 雲端拉取合併（remote wins）
    func syncFromCloud(userId: String) async {
        guard !userId.isEmpty else { return }
        do {
            let snap = try await collection(userId).getDocuments()
            let remote: [PlanningPreset] = snap.documents.compactMap { doc in
                var dict = doc.data()
                dict.removeValue(forKey: "updatedAt")
                guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                return try? JSONDecoder().decode(PlanningPreset.self, from: data)
            }
            guard !remote.isEmpty else { return }
            let remoteIds = Set(remote.map(\.id))
            let localOnly = load(userId: userId).filter { !remoteIds.contains($0.id) }
            await MainActor.run { saveLocal((remote + localOnly).sorted { $0.lastUsedAt > $1.lastUsedAt }, userId: userId) }
            for p in localOnly { await syncUp(p, userId: userId) }
        } catch {
            print("⚠️ [PlanningPresetStore] 拉取失敗: \(error.localizedDescription)")
        }
    }
}
