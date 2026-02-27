//
//  InfluenceDataManager.swift
//  Secalender
//
//  影響力數據管理：統計、活動紀錄、成就計算，與 Firestore 同步
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class InfluenceDataManager: ObservableObject {
    static let shared = InfluenceDataManager()
    private let db = Firestore.firestore()
    
    private let influenceStatsKey = "influence_stats"
    private let activityLogsKey = "activity_logs"
    
    @Published private(set) var stats: InfluenceStats = .default
    @Published private(set) var publishingHistory: [ActivityLog] = []
    @Published private(set) var isLoading = false
    
    private init() {}
    
    // MARK: - 載入
    
    func load(for userId: String) async {
        guard !userId.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let doc = try await db.collection("users").document(userId).collection(influenceStatsKey).document("current").getDocument()
            if let data = doc.data() {
                stats = parseStats(from: data)
            } else {
                stats = .default
            }
            
            let logsSnapshot = try await db.collection("users").document(userId).collection(activityLogsKey)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            publishingHistory = logsSnapshot.documents.compactMap { doc in
                parseActivityLog(from: doc)
            }
        } catch {
            print("⚠️ InfluenceDataManager load error: \(error.localizedDescription)")
            stats = .default
            publishingHistory = []
        }
    }
    
    private func parseStats(from data: [String: Any]) -> InfluenceStats {
        InfluenceStats(
            level: data["level"] as? Int ?? 1,
            expCurrent: data["expCurrent"] as? Int ?? 0,
            expNeeded: data["expNeeded"] as? Int ?? 100,
            eventsCreated: data["eventsCreated"] as? Int ?? 0,
            eventsParticipated: data["eventsParticipated"] as? Int ?? 0,
            templatesCreated: data["templatesCreated"] as? Int ?? 0,
            themesCreated: data["themesCreated"] as? Int ?? 0,
            aiUsageCount: data["aiUsageCount"] as? Int ?? 0,
            weeklyViews: data["weeklyViews"] as? Int ?? 0,
            weeklyEngagement: data["weeklyEngagement"] as? Int ?? 0,
            weeklyShares: data["weeklyShares"] as? Int ?? 0,
            lastWeekViews: data["lastWeekViews"] as? Int ?? 0,
            lastWeekEngagement: data["lastWeekEngagement"] as? Int ?? 0,
            lastWeekShares: data["lastWeekShares"] as? Int ?? 0,
            consecutiveCreateDays: data["consecutiveCreateDays"] as? Int ?? 0,
            lastCreateDate: data["lastCreateDate"] as? String,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }
    
    private func parseActivityLog(from doc: DocumentSnapshot) -> ActivityLog? {
        guard let data = doc.data(),
              let typeRaw = data["type"] as? String,
              let type = ActivityLogType(rawValue: typeRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else { return nil }
        var log = ActivityLog(
            type: type,
            title: data["title"] as? String,
            itemId: data["itemId"] as? String,
            visibility: data["visibility"] as? String,
            metadata: nil,
            createdAt: createdAt
        )
        log.id = doc.documentID
        return log
    }
    
    // MARK: - 記錄活動（內部呼叫，由 ActivityRecorder 統一觸發）
    
    func recordEventCreated(userId: String, title: String, eventId: String, visibility: Int) async {
        await incrementStats(userId: userId, updates: [
            "eventsCreated": FieldValue.increment(Int64(1)),
            "expCurrent": FieldValue.increment(Int64(10))
        ])
        await updateConsecutiveCreate(userId: userId)
        await addActivityLog(userId: userId, type: .eventCreated, title: title, itemId: eventId, visibility: visibilityString(visibility))
    }
    
    func recordEventParticipated(userId: String) async {
        await incrementStats(userId: userId, updates: [
            "eventsParticipated": FieldValue.increment(Int64(1)),
            "expCurrent": FieldValue.increment(Int64(5))
        ])
        await addActivityLog(userId: userId, type: .eventParticipated)
    }
    
    func recordTemplateCreated(userId: String, title: String) async {
        await incrementStats(userId: userId, updates: [
            "templatesCreated": FieldValue.increment(Int64(1)),
            "expCurrent": FieldValue.increment(Int64(15))
        ])
        await updateConsecutiveCreate(userId: userId)
        await addActivityLog(userId: userId, type: .templateCreated, title: title)
    }
    
    func recordThemeCreated(userId: String, title: String) async {
        await incrementStats(userId: userId, updates: [
            "themesCreated": FieldValue.increment(Int64(1)),
            "expCurrent": FieldValue.increment(Int64(12))
        ])
        await updateConsecutiveCreate(userId: userId)
        await addActivityLog(userId: userId, type: .themeCreated, title: title)
    }
    
    func recordAIUsed(userId: String) async {
        await incrementStats(userId: userId, updates: [
            "aiUsageCount": FieldValue.increment(Int64(1)),
            "expCurrent": FieldValue.increment(Int64(3))
        ])
        await addActivityLog(userId: userId, type: .aiUsed)
    }
    
    func recordContentPublished(userId: String, title: String, type: String, visibility: String) async {
        await addActivityLog(userId: userId, type: .contentPublished, title: title, visibility: visibility, metadata: ["contentType": type])
    }
    
    private func visibilityString(_ v: Int) -> String {
        switch v {
        case 1: return "public"
        case 2: return "friends"
        default: return "private"
        }
    }
    
    private func incrementStats(userId: String, updates: [String: FieldValue]) async {
        let ref = db.collection("users").document(userId).collection(influenceStatsKey).document("current")
        var data: [String: Any] = updates
        data["updatedAt"] = FieldValue.serverTimestamp()
        
        do {
            try await ref.setData(data, merge: true)
            await load(for: userId)
        } catch {
            print("⚠️ InfluenceDataManager incrementStats error: \(error.localizedDescription)")
        }
    }
    
    private func updateConsecutiveCreate(userId: String) async {
        let today = dateString(Date())
        let ref = db.collection("users").document(userId).collection(influenceStatsKey).document("current")
        
        do {
            let doc = try await ref.getDocument()
            let last = doc.data()?["lastCreateDate"] as? String
            let current = doc.data()?["consecutiveCreateDays"] as? Int ?? 0
            
            var newConsecutive = 1
            if let last = last {
                if let lastDate = parseDate(last), let todayDate = parseDate(today) {
                    let days = Calendar.current.dateComponents([.day], from: lastDate, to: todayDate).day ?? 0
                    if days == 1 {
                        newConsecutive = current + 1
                    } else if days > 1 {
                        newConsecutive = 1
                    } else {
                        newConsecutive = current
                    }
                }
            }
            
            try await ref.setData([
                "lastCreateDate": today,
                "consecutiveCreateDays": newConsecutive,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
            await load(for: userId)
        } catch {
            print("⚠️ InfluenceDataManager updateConsecutiveCreate error: \(error.localizedDescription)")
        }
    }
    
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
    
    private func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
    
    /// 僅寫入 activity_logs（不更新 influence_stats），用於 Cloud Function 發放 XP 時
    func addActivityLogOnly(userId: String, type: ActivityLogType, title: String? = nil, itemId: String? = nil, visibility: String? = nil, metadata: [String: String]? = nil) async {
        await addActivityLog(userId: userId, type: type, title: title, itemId: itemId, visibility: visibility, metadata: metadata)
    }

    private func addActivityLog(userId: String, type: ActivityLogType, title: String? = nil, itemId: String? = nil, visibility: String? = nil, metadata: [String: String]? = nil) async {
        let ref = db.collection("users").document(userId).collection(activityLogsKey).document()
        var data: [String: Any] = [
            "type": type.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let t = title { data["title"] = t }
        if let i = itemId { data["itemId"] = i }
        if let v = visibility { data["visibility"] = v }
        if let m = metadata { data["metadata"] = m }
        
        do {
            try await ref.setData(data)
            await load(for: userId)
        } catch {
            print("⚠️ InfluenceDataManager addActivityLog error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 成就計算
    
    func achievementProgress(for userId: String) -> [AchievementProgress] {
        var result: [AchievementProgress] = []
        for def in AchievementDefinition.allCases {
            let current = currentCount(for: def)
            let target = def.targetCount
            result.append(AchievementProgress(
                definition: def,
                current: current,
                isUnlocked: current >= target
            ))
        }
        return result
    }
    
    private func currentCount(for def: AchievementDefinition) -> Int {
        switch def {
        case .pioneer: return stats.eventsCreated >= 1 ? 1 : 0
        case .foodie: return min(stats.eventsCreated, 5)  // 簡化：用活動數
        case .photo: return stats.eventsCreated
        case .social: return stats.eventsParticipated
        case .collector: return 0  // 需從收藏 API 取得
        case .speed: return stats.consecutiveCreateDays
        case .globetrotter: return stats.eventsCreated
        case .earlyBird: return min(stats.eventsCreated, 3)
        case .familyTrips: return min(stats.eventsCreated, 3)
        case .lowCarbon: return min(stats.eventsCreated, 5)
        case .creator: return stats.themesCreated
        case .aiExplorer: return stats.aiUsageCount
        case .hiddenMystery: return 0  // 神秘條件，暫不顯示進度
        }
    }
    
    func unlockedAchievementsCount() -> Int {
        achievementProgress(for: "").filter { $0.isUnlocked }.count
    }
    
    func totalAchievementsCount() -> Int {
        AchievementDefinition.allCases.count
    }
}
