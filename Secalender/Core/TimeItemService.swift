//
//  TimeItemService.swift
//  Secalender
//
//  專責 time_items 的 CRUD、範圍查詢、浮動任務、批次更新
//  路徑：users/{uid}/time_items/{itemId}
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

final class TimeItemService {
    static let shared = TimeItemService()
    private let db = Firestore.firestore()
    private let collectionName = "time_items"
    
    /// 避免重複 query：同一範圍只載入一次
    private var lastFetchRange: (start: Date, end: Date)?
    private var cachedRangedItems: [TimeItem] = []
    
    private init() {}
    
    private func userId() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            throw TimeItemError.notAuthenticated
        }
        return uid
    }
    
    private func collectionRef() throws -> CollectionReference {
        let uid = try userId()
        return db.collection("users").document(uid).collection(collectionName)
    }
    
    // MARK: - 編碼/解碼

    private func encode(_ item: TimeItem) throws -> [String: Any] {
        var data: [String: Any] = [
            "type": item.type.rawValue,
            "title": item.title,
            "hasStartAt": item.hasStartAt,
            "source": item.source.rawValue,
            "status": item.status.rawValue
        ]
        if let notes = item.notes { data["notes"] = notes }
        if let startAt = item.startAt { data["startAt"] = Timestamp(date: startAt) }
        if let endAt = item.endAt { data["endAt"] = Timestamp(date: endAt) }
        if let durationMin = item.durationMin { data["durationMin"] = durationMin }
        if let deadlineAt = item.deadlineAt { data["deadlineAt"] = Timestamp(date: deadlineAt) }
        if let priority = item.priority { data["priority"] = priority }
        if let energyTag = item.energyTag { data["energyTag"] = energyTag }
        if let themeKey = item.themeKey { data["themeKey"] = themeKey }
        if let requestId = item.requestId { data["requestId"] = requestId }
        if let templateId = item.templateId { data["templateId"] = templateId }
        if let linkedTaskId = item.linkedTaskId { data["linkedTaskId"] = linkedTaskId }
        data["createdAt"] = Timestamp(date: item.createdAt ?? Date())
        data["updatedAt"] = FieldValue.serverTimestamp()
        return data
    }
    
    private func decode(_ document: DocumentSnapshot) -> TimeItem? {
        guard let data = document.data() else { return nil }
        let id = document.documentID
        
        guard let typeRaw = data["type"] as? String,
              let type = TimeItemType(rawValue: typeRaw),
              let title = data["title"] as? String,
              let hasStartAt = data["hasStartAt"] as? Bool,
              let sourceRaw = data["source"] as? String,
              let source = TimeItemSource(rawValue: sourceRaw),
              let statusRaw = data["status"] as? String,
              let status = TimeItemStatus(rawValue: statusRaw) else {
            return nil
        }
        
        let startAt = (data["startAt"] as? Timestamp)?.dateValue()
        let endAt = (data["endAt"] as? Timestamp)?.dateValue()
        let deadlineAt = (data["deadlineAt"] as? Timestamp)?.dateValue()
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        
        return TimeItem(
            id: id,
            type: type,
            title: title,
            notes: data["notes"] as? String,
            startAt: startAt,
            endAt: endAt,
            hasStartAt: hasStartAt,
            durationMin: data["durationMin"] as? Int,
            deadlineAt: deadlineAt,
            priority: data["priority"] as? Int,
            energyTag: data["energyTag"] as? String,
            themeKey: data["themeKey"] as? String,
            requestId: data["requestId"] as? String,
            templateId: data["templateId"] as? String,
            source: source,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            linkedTaskId: data["linkedTaskId"] as? String
        )
    }
    
    // MARK: - 寫入

    /// 新增或更新
    func upsert(_ item: TimeItem) async throws -> String {
        let ref = try collectionRef()
        var data = try encode(item)
        data["updatedAt"] = FieldValue.serverTimestamp()
        
        if let existingId = item.id, !existingId.isEmpty {
            try await ref.document(existingId).setData(data, merge: true)
            print("✅ [TimeItemService] 更新: \(existingId)")
            return existingId
        } else {
            let docRef = ref.document()
            try await docRef.setData(data)
            print("✅ [TimeItemService] 新增: \(docRef.documentID)")
            return docRef.documentID
        }
    }
    
    /// 依 id 取得單一項目
    func fetchById(_ itemId: String) async throws -> TimeItem? {
        let ref = try collectionRef()
        let doc = try await ref.document(itemId).getDocument()
        return doc.exists ? decode(doc) : nil
    }
    
    /// 刪除
    func delete(itemId: String) async throws {
        let ref = try collectionRef()
        try await ref.document(itemId).delete()
        print("✅ [TimeItemService] 刪除: \(itemId)")
    }
    
    // MARK: - 查詢

    /// 範圍查詢：startAt 落在 [rangeStart, rangeEnd] 內
    /// 用於日曆月視圖載入
    func fetchRanged(rangeStart: Date, rangeEnd: Date) async throws -> [TimeItem] {
        let ref = try collectionRef()
        
        let query = ref
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: rangeStart))
            .whereField("startAt", isLessThanOrEqualTo: Timestamp(date: rangeEnd))
            .whereField("status", isEqualTo: TimeItemStatus.active.rawValue)
        
        let snapshot = try await query.getDocuments()
        let items = snapshot.documents.compactMap { decode($0) }
        
        // 客戶端過濾：只取 event, block, availability, suggestion
        let displayTypes: Set<TimeItemType> = [.event, .block, .availability, .suggestion]
        return items.filter { displayTypes.contains($0.type) }
    }
    
    /// 浮動任務：type=task, hasStartAt=false, status=active
    func fetchFloatingTasks() async throws -> [TimeItem] {
        let ref = try collectionRef()
        
        let query = ref
            .whereField("type", isEqualTo: TimeItemType.task.rawValue)
            .whereField("hasStartAt", isEqualTo: false)
            .whereField("status", isEqualTo: TimeItemStatus.active.rawValue)
        
        let snapshot = try await query.getDocuments()
        var items = snapshot.documents.compactMap { decode($0) }
        
        // 客戶端排序：deadline 升序、priority 降序
        items.sort { a, b in
            let aDeadline = a.deadlineAt ?? .distantFuture
            let bDeadline = b.deadlineAt ?? .distantFuture
            if aDeadline != bDeadline { return aDeadline < bDeadline }
            return (a.priority ?? 3) >= (b.priority ?? 3)
        }
        return items
    }
    
    /// 取得所有固定事件（event/block）用於排程計算空檔
    func fetchFixedItems(rangeStart: Date, rangeEnd: Date) async throws -> [TimeItem] {
        let ref = try collectionRef()
        
        let query = ref
            .whereField("hasStartAt", isEqualTo: true)
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: rangeStart))
            .whereField("startAt", isLessThanOrEqualTo: Timestamp(date: rangeEnd))
            .whereField("status", isEqualTo: TimeItemStatus.active.rawValue)
        
        let snapshot = try await query.getDocuments()
        let items = snapshot.documents.compactMap { decode($0) }
        
        // 只取 event, block（排除 suggestion）
        return items.filter { $0.type == .event || $0.type == .block }
    }
    
    /// 衝突檢查：指定時間段是否與 block/event 重疊
    func hasConflict(start: Date, end: Date, excludingId: String? = nil) async throws -> Bool {
        let fixed = try await fetchFixedItems(rangeStart: start, rangeEnd: end)
        return fixed.contains { item in
            if item.id == excludingId { return false }
            guard let s = item.startAt, let e = item.endAt else { return false }
            return start < e && end > s
        }
    }
    
    // MARK: - 批次更新

    /// 批次更新（拖曳、套用 suggestion 時）
    func batchUpdate(_ items: [TimeItem]) async throws {
        let ref = try collectionRef()
        let batch = db.batch()
        
        for item in items {
            guard let id = item.id, !id.isEmpty else { continue }
            var data = try encode(item)
            data["updatedAt"] = FieldValue.serverTimestamp()
            batch.setData(data, forDocument: ref.document(id), merge: true)
        }
        
        try await batch.commit()
        print("✅ [TimeItemService] 批次更新 \(items.count) 筆")
    }
}

// MARK: - 錯誤

enum TimeItemError: LocalizedError {
    case notAuthenticated
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "用戶未登入"
        case .invalidData: return "資料格式錯誤"
        }
    }
}
