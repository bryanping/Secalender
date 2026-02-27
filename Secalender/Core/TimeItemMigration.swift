//
//  TimeItemMigration.swift
//  Secalender
//
//  一次性遷移工具：舊 events → time_items(type=event)
//  避免重複匯入（用 migratedFlag 或 source=legacy）
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class TimeItemMigration {
    static let shared = TimeItemMigration()
    private let db = Firestore.firestore()
    private let migrationFlagKey = "time_item_migrated_v1"
    
    private init() {}
    
    private func userId() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            throw TimeItemError.notAuthenticated
        }
        return uid
    }
    
    /// 是否已完成遷移
    var hasMigrated: Bool {
        UserDefaults.standard.bool(forKey: migrationFlagKey)
    }
    
    /// 執行遷移：讀取 users/{uid}/events，轉為 time_items
    func migrate() async throws -> Int {
        guard !hasMigrated else { return 0 }
        
        let uid = try userId()
        let eventsRef = db.collection("users").document(uid).collection("events")
        let snapshot = try await eventsRef.getDocuments()
        
        let timeItemsRef = db.collection("users").document(uid).collection("time_items")
        var count = 0
        
        for doc in snapshot.documents {
            guard let data = doc.data() as [String: Any]?,
                  let title = data["title"] as? String,
                  let date = data["date"] as? String,
                  let startTime = data["startTime"] as? String,
                  let endTime = data["endTime"] as? String else { continue }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            
            guard let startDate = dateFormatter.date(from: date),
                  let startT = timeFormatter.date(from: startTime),
                  let endT = timeFormatter.date(from: endTime) else { continue }
            
            let cal = Calendar.current
            let startAt = cal.date(bySettingHour: cal.component(.hour, from: startT), minute: cal.component(.minute, from: startT), second: 0, of: startDate) ?? startDate
            let endDate = endTime.hasPrefix("23:59") ? cal.date(byAdding: .day, value: 1, to: startDate) : startDate
            let endAt = cal.date(bySettingHour: cal.component(.hour, from: endT), minute: cal.component(.minute, from: endT), second: 0, of: endDate ?? startDate) ?? startAt
            
            let item: [String: Any] = [
                "type": "event",
                "title": title,
                "hasStartAt": true,
                "source": "legacy",
                "status": "active",
                "startAt": Timestamp(date: startAt),
                "endAt": Timestamp(date: endAt),
                "notes": data["information"] as? String,
                "createdAt": Timestamp(date: Date()),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            try await timeItemsRef.document("legacy_\(doc.documentID)").setData(item, merge: true)
            count += 1
        }
        
        if count > 0 {
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
        }
        return count
    }
}
