//
//  EventManager.swift
//  Secalender
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import SwiftUI // 用于获取环境对象

// 导入必要的模型和管理器
// 导入用户管理器
// 导入缓存管理器

class EventManager {
    static let shared = EventManager()
    private init() {}

    private let db = Firestore.firestore()

    /// 新增活动
    func addEvent(event: Event) async throws {
        var newEvent = event
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        newEvent.createTime = formatter.string(from: now)
        
        // 获取当前用户ID
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        // 先保存到本地缓存（立即响应）
        EventCacheManager.shared.addEventToCache(newEvent, for: userId)
        
        // 尝试保存到 Firestore（后台同步）
        do {
            // 生成文档ID并转换为Int（使用哈希值）
            let documentId = UUID().uuidString
            let intId = abs(documentId.hashValue)
            newEvent.id = intId
            
            if let groupId = newEvent.groupId {
                // 社群事件：保存到 groups/{groupId}/groupEvents 子集合
                var groupEventData = try Firestore.Encoder().encode(newEvent)
                groupEventData["eventId"] = documentId
                groupEventData["groupId"] = groupId
                try await db.collection("groups").document(groupId).collection("groupEvents").document(documentId).setData(groupEventData)
                print("✅ 社群活动保存成功: groupId=\(groupId), eventId=\(intId)")
            } else {
                // 个人事件：保存到 users/{userId}/events 子集合
                var userEventData = try Firestore.Encoder().encode(newEvent)
                userEventData["eventId"] = documentId
                try await db.collection("users").document(userId).collection("events").document(documentId).setData(userEventData)
                print("✅ 个人活动保存成功: userId=\(userId), eventId=\(intId)")
            }
            
            // 更新本地缓存中的事件ID
            EventCacheManager.shared.addEventToCache(newEvent, for: userId)
        } catch {
            print("⚠️ Firebase保存失败，但已保存到本地缓存: \(error.localizedDescription)")
            // 即使Firebase失败，本地缓存已保存，可以继续使用
        }
    }

    /// 更新活动
    func updateEvent(event: Event) async throws {
        guard let eventId = event.id else {
            throw NSError(domain: "EventManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "活动ID不存在"])
        }

        // 获取当前用户ID
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }

        // 不修改createTime，保持原始创建时间
        let updatedEvent = event

        // 先更新本地缓存（立即响应）
        EventCacheManager.shared.updateEventInCache(updatedEvent, for: userId)

        // 尝试更新到 Firestore（后台同步）
        do {
            // 根据事件类型查找文档
            if let groupId = updatedEvent.groupId {
                // 社群事件：在 groups/{groupId}/groupEvents 中查找
                let groupEventsSnapshot = try await db.collection("groups")
                    .document(groupId)
                    .collection("groupEvents")
                    .whereField("id", isEqualTo: eventId)
                    .getDocuments()
                
                if let document = groupEventsSnapshot.documents.first {
                    var groupEventData = try Firestore.Encoder().encode(updatedEvent)
                    groupEventData["groupId"] = groupId
                    if let eventId = document.data()["eventId"] as? String {
                        groupEventData["eventId"] = eventId
                    }
                    try await document.reference.setData(groupEventData, merge: true)
                    print("✅ 社群活动更新成功: ID \(eventId)")
                } else {
                    print("⚠️ Firebase中找不到社群活动，但已更新本地缓存: ID \(eventId)")
                }
            } else {
                // 个人事件：在 users/{userId}/events 中查找
                let userEventsSnapshot = try await db.collection("users")
                    .document(userId)
                    .collection("events")
                    .whereField("id", isEqualTo: eventId)
                    .getDocuments()
                
                if let document = userEventsSnapshot.documents.first {
                    var userEventData = try Firestore.Encoder().encode(updatedEvent)
                    if let eventId = document.data()["eventId"] as? String {
                        userEventData["eventId"] = eventId
                    }
                    try await document.reference.setData(userEventData, merge: true)
                    print("✅ 个人活动更新成功: ID \(eventId)")
                } else {
                    print("⚠️ Firebase中找不到个人活动，但已更新本地缓存: ID \(eventId)")
                }
            }
        } catch {
            print("⚠️ Firebase更新失败，但已更新本地缓存: \(error.localizedDescription)")
            // 即使Firebase失败，本地缓存已更新，可以继续使用
        }
    }
    
    /// 只更新 Firebase（不更新本地缓存，用于后台同步）
    /// 注意：调用此方法前应该已经更新了本地缓存
    func updateEventInFirebaseOnly(event: Event) async throws {
        guard let eventId = event.id else {
            throw NSError(domain: "EventManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "活动ID不存在"])
        }
        
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        // 只更新 Firebase，不更新本地缓存
        if let groupId = event.groupId {
            let groupEventsSnapshot = try await db.collection("groups")
                .document(groupId)
                .collection("groupEvents")
                .whereField("id", isEqualTo: eventId)
                .getDocuments()
            
            if let document = groupEventsSnapshot.documents.first {
                var groupEventData = try Firestore.Encoder().encode(event)
                groupEventData["groupId"] = groupId
                if let eventIdString = document.data()["eventId"] as? String {
                    groupEventData["eventId"] = eventIdString
                }
                try await document.reference.setData(groupEventData, merge: true)
                print("✅ 社群活动 Firebase 更新成功: ID \(eventId)")
            }
        } else {
            let userEventsSnapshot = try await db.collection("users")
                .document(userId)
                .collection("events")
                .whereField("id", isEqualTo: eventId)
                .getDocuments()
            
            if let document = userEventsSnapshot.documents.first {
                var userEventData = try Firestore.Encoder().encode(event)
                if let eventIdString = document.data()["eventId"] as? String {
                    userEventData["eventId"] = eventIdString
                }
                try await document.reference.setData(userEventData, merge: true)
                print("✅ 个人活动 Firebase 更新成功: ID \(eventId)")
            }
        }
    }
    
    /// 只添加到 Firebase（不更新本地缓存，用于后台同步）
    /// 注意：调用此方法前应该已经添加到本地缓存
    func addEventToFirebaseOnly(event: Event) async throws {
        var newEvent = event
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        newEvent.createTime = formatter.string(from: now)
        
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        // 只添加到 Firebase，不更新本地缓存
        let documentId = UUID().uuidString
        let intId = abs(documentId.hashValue)
        newEvent.id = intId
        
        if let groupId = newEvent.groupId {
            var groupEventData = try Firestore.Encoder().encode(newEvent)
            groupEventData["eventId"] = documentId
            groupEventData["groupId"] = groupId
            try await db.collection("groups").document(groupId).collection("groupEvents").document(documentId).setData(groupEventData)
            print("✅ 社群活动 Firebase 保存成功: groupId=\(groupId), eventId=\(intId)")
        } else {
            var userEventData = try Firestore.Encoder().encode(newEvent)
            userEventData["eventId"] = documentId
            try await db.collection("users").document(userId).collection("events").document(documentId).setData(userEventData)
            print("✅ 个人活动 Firebase 保存成功: userId=\(userId), eventId=\(intId)")
        }
        
        // 更新本地缓存中的事件ID（因为 Firebase 生成了新的 ID）
        EventCacheManager.shared.updateEventInCache(newEvent, for: userId)
    }

    /// 读取所有活动（优先使用本地缓存，后台同步Firebase）
    /// 从 users/{userId}/events 和 groups/{groupId}/groupEvents 拉取
    func fetchEvents() async throws -> [Event] {
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else {
            return []
        }
        
        // 1. 先从本地缓存加载（立即返回）
        var cachedEvents = EventCacheManager.shared.loadEvents(for: userId)
        
        // 2. 尝试从Firebase获取最新数据（后台同步）
        do {
            var allEvents: [Event] = []
            
            // 2.1 拉取个人事件：users/{userId}/events
            let userEventsSnapshot = try await db.collection("users")
                .document(userId)
                .collection("events")
                .getDocuments()
            
            let userEvents = userEventsSnapshot.documents.compactMap { document -> Event? in
                return parseEventFromDocument(document)
            }
            allEvents.append(contentsOf: userEvents)
            print("✅ 从 users/\(userId)/events 加载了 \(userEvents.count) 个个人事件")
            
            // 2.2 拉取社群事件：获取用户加入的所有社群，然后从每个社群的 groupEvents 拉取
            // 修改内容：使用并行查询代替串行循环，提升性能
            let groupsSnapshot = try await db.collection("groups")
                .whereField("members", arrayContains: userId)
                .getDocuments()
            
            let groupIds = groupsSnapshot.documents.map { $0.documentID }
            
            // 使用 TaskGroup 并行查询所有社群的事件
            if !groupIds.isEmpty {
                try await withThrowingTaskGroup(of: (String, [Event]).self) { group in
                    for groupId in groupIds {
                        group.addTask { [weak self] in
                            guard let self = self else { return (groupId, []) }
                            do {
                                let groupEventsSnapshot = try await self.db.collection("groups")
                                    .document(groupId)
                                    .collection("groupEvents")
                                    .getDocuments()
                                
                                let groupEvents = groupEventsSnapshot.documents.compactMap { document -> Event? in
                                    return self.parseEventFromDocument(document)
                                }
                                print("✅ 从 groups/\(groupId)/groupEvents 加载了 \(groupEvents.count) 个社群事件")
                                return (groupId, groupEvents)
                            } catch {
                                print("⚠️ 加载社群 \(groupId) 的事件失败: \(error.localizedDescription)")
                                return (groupId, [])
                            }
                        }
                    }
                    
                    // 收集所有结果
                    for try await (_, groupEvents) in group {
                        allEvents.append(contentsOf: groupEvents)
                    }
                }
            }
            
            // 3. 更新本地缓存
            EventCacheManager.shared.saveEvents(allEvents, for: userId)
            
            print("✅ 从Firebase总共加载了 \(allEvents.count) 个事件，已更新本地缓存")
            return allEvents
        } catch {
            // 4. 如果Firebase失败，使用本地缓存
            print("⚠️ Firebase读取失败，使用本地缓存: \(error.localizedDescription)")
            if !cachedEvents.isEmpty {
                print("📦 使用本地缓存: \(cachedEvents.count) 个事件")
                return cachedEvents
            }
            // 如果本地缓存也为空，抛出错误
            throw error
        }
    }
    
    /// 从 Firestore 文档解析 Event
    private func parseEventFromDocument(_ document: QueryDocumentSnapshot) -> Event? {
        do {
            let data = document.data()
            
            // 手动解析，处理缺失字段和类型不匹配
            var event = Event()
            
            // 基本字段
            event.id = data["id"] as? Int ?? abs(document.documentID.hashValue)
            event.title = data["title"] as? String ?? ""
            event.creatorOpenid = data["creatorOpenid"] as? String ?? ""
            event.color = data["color"] as? String ?? "#FF0000" // 默认红色
            
            // 处理date字段：可能是String或Timestamp
            if let dateString = data["date"] as? String {
                event.date = dateString
            } else if let timestamp = data["date"] as? Timestamp {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                event.date = formatter.string(from: timestamp.dateValue())
            } else {
                event.date = ""
            }
            
            event.startTime = data["startTime"] as? String ?? ""
            event.endTime = data["endTime"] as? String ?? ""
            event.endDate = data["endDate"] as? String
            event.destination = data["destination"] as? String ?? ""
            event.mapObj = data["mapObj"] as? String ?? ""
            event.openChecked = data["openChecked"] as? Int ?? 0
            event.personChecked = data["personChecked"] as? Int ?? 0
            event.personNumber = data["personNumber"] as? Int
            event.sponsorType = data["sponsorType"] as? String
            event.category = data["category"] as? String
            event.createTime = data["createTime"] as? String ?? ""
            event.deleted = data["deleted"] as? Int
            event.information = data["information"] as? String
            event.groupId = data["groupId"] as? String
            event.isAllDay = data["isAllDay"] as? Bool ?? false
            event.repeatType = data["repeatType"] as? String ?? "never"
            event.calendarComponent = data["calendarComponent"] as? String ?? "default"
            event.travelTime = data["travelTime"] as? String
            event.invitees = data["invitees"] as? [String]
            
            return event
        } catch {
            print("解析事件失败: \(error)")
            return nil
        }
    }
    
    /// 从本地缓存读取事件（不访问Firebase）
    func fetchEventsFromCache() -> [Event] {
        let userId = Auth.auth().currentUser?.uid ?? ""
        return EventCacheManager.shared.loadEvents(for: userId)
    }
    
    /// 软删除活动（设置 deleted = 1，保留记录）
    func softDeleteEvent(eventId: Int) async throws {
        print("尝试软删除活动，ID: \(eventId)")
        
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        // 先更新本地缓存（立即响应）
        if !userId.isEmpty {
            if var cachedEvent = EventCacheManager.shared.loadEvents(for: userId).first(where: { $0.id == eventId }) {
                cachedEvent.deleted = 1
                EventCacheManager.shared.updateEventInCache(cachedEvent, for: userId)
            }
        }
        
        // 更新 Firebase（后台同步）
        do {
            // 先尝试从个人事件中更新
            let userEventsSnapshot = try await db.collection("users")
                .document(userId)
                .collection("events")
                .whereField("id", isEqualTo: eventId)
                .getDocuments()
            
            if let userEventDoc = userEventsSnapshot.documents.first {
                try await userEventDoc.reference.updateData(["deleted": 1])
                print("✅ 个人活动软删除成功: ID \(eventId)")
                return
            }
            
            // 如果不是个人事件，尝试从所有社群的 groupEvents 中更新
            let groupsSnapshot = try await db.collection("groups")
                .whereField("members", arrayContains: userId)
                .getDocuments()
            
            for groupDoc in groupsSnapshot.documents {
                let groupId = groupDoc.documentID
                let groupEventsSnapshot = try await db.collection("groups")
                    .document(groupId)
                    .collection("groupEvents")
                    .whereField("id", isEqualTo: eventId)
                    .getDocuments()
                
                if let groupEventDoc = groupEventsSnapshot.documents.first {
                    try await groupEventDoc.reference.updateData(["deleted": 1])
                    print("✅ 社群活动软删除成功: groupId=\(groupId), eventId=\(eventId)")
                    return
                }
            }
            
            print("⚠️ Firebase中找不到活动，但已更新本地缓存: ID \(eventId)")
        } catch {
            print("⚠️ Firebase软删除失败，但已更新本地缓存: \(error.localizedDescription)")
        }
    }
    
    /// 更新事件日期
    func updateEventDate(eventId: Int, newDate: String, newStartTime: String? = nil, newEndTime: String? = nil, newEndDate: String? = nil) async throws {
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        var updateData: [String: Any] = ["date": newDate]
        if let startTime = newStartTime {
            updateData["startTime"] = startTime
        }
        if let endTime = newEndTime {
            updateData["endTime"] = endTime
        }
        if let endDate = newEndDate {
            updateData["endDate"] = endDate
        } else {
            // 如果没有提供结束日期，但原来有结束日期，需要清除它
            // 这里我们不做清除，保持原有逻辑
        }
        
        // 先更新本地缓存
        if !userId.isEmpty {
            if var cachedEvent = EventCacheManager.shared.loadEvents(for: userId).first(where: { $0.id == eventId }) {
                cachedEvent.date = newDate
                if let startTime = newStartTime {
                    cachedEvent.startTime = startTime
                }
                if let endTime = newEndTime {
                    cachedEvent.endTime = endTime
                }
                if let endDate = newEndDate {
                    cachedEvent.endDate = endDate
                }
                EventCacheManager.shared.updateEventInCache(cachedEvent, for: userId)
            }
        }
        
        // 更新 Firebase
        do {
            // 先尝试从个人事件中更新
            let userEventsSnapshot = try await db.collection("users")
                .document(userId)
                .collection("events")
                .whereField("id", isEqualTo: eventId)
                .getDocuments()
            
            if let userEventDoc = userEventsSnapshot.documents.first {
                try await userEventDoc.reference.updateData(updateData)
                print("✅ 个人活动日期更新成功: ID \(eventId)")
                return
            }
            
            // 如果不是个人事件，尝试从所有社群的 groupEvents 中更新
            let groupsSnapshot = try await db.collection("groups")
                .whereField("members", arrayContains: userId)
                .getDocuments()
            
            for groupDoc in groupsSnapshot.documents {
                let groupId = groupDoc.documentID
                let groupEventsSnapshot = try await db.collection("groups")
                    .document(groupId)
                    .collection("groupEvents")
                    .whereField("id", isEqualTo: eventId)
                    .getDocuments()
                
                if let groupEventDoc = groupEventsSnapshot.documents.first {
                    try await groupEventDoc.reference.updateData(updateData)
                    print("✅ 社群活动日期更新成功: groupId=\(groupId), eventId=\(eventId)")
                    return
                }
            }
            
            print("⚠️ Firebase中找不到活动，但已更新本地缓存: ID \(eventId)")
        } catch {
            print("⚠️ Firebase日期更新失败，但已更新本地缓存: \(error.localizedDescription)")
        }
    }
    
    /// 删除活动（硬删除，真正删除记录）
    func deleteEvent(eventId: Int) async throws {
        print("尝试删除活动，ID: \(eventId)")
        
        let userId = Auth.auth().currentUser?.uid ?? ""
        
        // 先从本地缓存删除（立即响应）
        if !userId.isEmpty {
            EventCacheManager.shared.removeEventFromCache(eventId: eventId, for: userId)
        }
        
        // 尝试从Firebase删除（后台同步）
        do {
        // 根据事件类型删除
        let userId = Auth.auth().currentUser?.uid ?? ""
        guard !userId.isEmpty else {
            print("⚠️ 用户未登录，无法删除")
            return
        }
        
        // 先尝试从个人事件中删除
        let userEventsSnapshot = try await db.collection("users")
            .document(userId)
            .collection("events")
            .whereField("id", isEqualTo: eventId)
            .getDocuments()
        
        if let userEventDoc = userEventsSnapshot.documents.first {
            try await userEventDoc.reference.delete()
            print("✅ 个人活动删除成功: ID \(eventId)")
            return
        }
        
        // 如果不是个人事件，尝试从所有社群的 groupEvents 中删除
        let groupsSnapshot = try await db.collection("groups")
            .whereField("members", arrayContains: userId)
            .getDocuments()
        
        for groupDoc in groupsSnapshot.documents {
            let groupId = groupDoc.documentID
            let groupEventsSnapshot = try await db.collection("groups")
                .document(groupId)
                .collection("groupEvents")
                .whereField("id", isEqualTo: eventId)
                .getDocuments()
            
            for groupEventDoc in groupEventsSnapshot.documents {
                try await groupEventDoc.reference.delete()
                print("✅ 社群活动删除成功: groupId=\(groupId), eventId=\(eventId)")
                return
            }
        }
        
        print("⚠️ Firebase中找不到活动，但已从本地缓存删除: ID \(eventId)")
        
            print("⚠️ Firebase中找不到活动，但已从本地缓存删除: ID \(eventId)")
        } catch {
            print("⚠️ Firebase删除失败，但已从本地缓存删除: \(error.localizedDescription)")
            // 即使Firebase失败，本地缓存已删除，可以继续使用
        }
    }
    
    /// 分享活动给好友
    func shareEventWithFriends(eventId: Int, friendIds: [String], senderId: String? = nil) async throws {
        guard !friendIds.isEmpty else { return }
        
        // 确定发送者ID
        let senderUserId: String
        if let senderId = senderId, !senderId.isEmpty {
            senderUserId = senderId
        } else if let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty {
            senderUserId = currentUserId
        } else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        let batch = db.batch()
        let timestamp = FieldValue.serverTimestamp()
        
        for friendId in friendIds {
            // 创建分享记录
            let shareRef = db.collection("event_shares").document()
            batch.setData([
                "eventId": eventId,
                "senderId": senderUserId,
                "receiverId": friendId,
                "sharedAt": timestamp,
                "status": "shared"
            ], forDocument: shareRef)
            
            // 创建通知
            let notificationRef = db.collection("notifications").document()
            batch.setData([
                "id": notificationRef.documentID,
                "eventId": eventId,
                "senderId": senderUserId,
                "receiverId": friendId,
                "type": "event_shared",
                "createdAt": timestamp,
                "isRead": false,
                "status": "pending"
            ], forDocument: notificationRef)
        }
        
        try await batch.commit()
    }
    
    /// 批量分享多个活动给好友（用于多行程分享）
    /// - Parameters:
    ///   - eventIds: 要分享的事件ID列表
    ///   - friendIds: 好友ID列表
    ///   - senderId: 发送者ID（可选，默认使用当前用户）
    func shareMultipleEventsWithFriends(eventIds: [Int], friendIds: [String], senderId: String? = nil) async throws {
        guard !eventIds.isEmpty && !friendIds.isEmpty else { return }
        
        // 确定发送者ID
        let senderUserId: String
        if let senderId = senderId, !senderId.isEmpty {
            senderUserId = senderId
        } else if let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty {
            senderUserId = currentUserId
        } else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        // Firebase 批量操作最多支持 500 个操作
        // 分批处理，每批最多 400 个操作（每个事件 x 每个好友 = 2 个操作）
        let batchSize = 400
        var operationCount = 0
        
        var batch = db.batch()
        let timestamp = FieldValue.serverTimestamp()
        
        for eventId in eventIds {
            for friendId in friendIds {
                // 创建分享记录
                let shareRef = db.collection("event_shares").document()
                batch.setData([
                    "eventId": eventId,
                    "senderId": senderUserId,
                    "receiverId": friendId,
                    "sharedAt": timestamp,
                    "status": "shared"
                ], forDocument: shareRef)
                operationCount += 1
                
                // 创建通知（仅对第一个事件创建通知，避免重复通知）
                if eventId == eventIds.first {
                    let notificationRef = db.collection("notifications").document()
                    batch.setData([
                        "id": notificationRef.documentID,
                        "eventId": eventId,
                        "senderId": senderUserId,
                        "receiverId": friendId,
                        "type": "event_shared",
                        "createdAt": timestamp,
                        "isRead": false,
                        "status": "pending"
                    ], forDocument: notificationRef)
                    operationCount += 1
                }
                
                // 如果达到批次大小，提交当前批次并创建新批次
                if operationCount >= batchSize {
                    try await batch.commit()
                    batch = db.batch()
                    operationCount = 0
                }
            }
        }
        
        // 提交剩余的操作
        if operationCount > 0 {
            try await batch.commit()
        }
        
        print("✅ 批量分享了 \(eventIds.count) 个事件给 \(friendIds.count) 个好友")
    }
    
    /// 获取与指定事件相关的多行程事件（通过 createTime 匹配）
    /// - Parameters:
    ///   - event: 当前事件
    ///   - allEvents: 所有事件列表
    /// - Returns: 相关的多行程事件列表（包括当前事件）
    func getRelatedMultiDayEvents(event: Event, from allEvents: [Event]) -> [Event] {
        // 如果事件没有 createTime，只返回当前事件
        guard !event.createTime.isEmpty else {
            return [event]
        }
        
        // 查找所有具有相同 createTime 的事件（同一批次的多行程）
        let relatedEvents = allEvents.filter { otherEvent in
            otherEvent.createTime == event.createTime &&
            otherEvent.creatorOpenid == event.creatorOpenid
        }
        
        // 按日期和开始时间排序
        return relatedEvents.sorted { event1, event2 in
            if let date1 = event1.dateObj, let date2 = event2.dateObj {
                if date1 != date2 {
                    return date1 < date2
                }
            }
            if let time1 = event1.startDateTime, let time2 = event2.startDateTime {
                return time1 < time2
            }
            return false
        }
    }
    
    /// 邀请好友参加活动
    func inviteFriendsToEvent(eventId: Int, friendIds: [String], senderId: String? = nil) async throws {
        guard !friendIds.isEmpty else { return }
        
        // 确定发送者ID
        let senderUserId: String
        if let senderId = senderId, !senderId.isEmpty {
            senderUserId = senderId
        } else if let currentUserId = Auth.auth().currentUser?.uid, !currentUserId.isEmpty {
            senderUserId = currentUserId
        } else {
            throw NSError(domain: "EventManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"])
        }
        
        let batch = db.batch()
        let timestamp = FieldValue.serverTimestamp()
        
        for friendId in friendIds {
            // 创建邀请记录
            let invitationRef = db.collection("event_invitations").document()
            batch.setData([
                "eventId": eventId,
                "senderId": senderUserId,
                "receiverId": friendId,
                "invitedAt": timestamp,
                "status": "pending"
            ], forDocument: invitationRef)
            
            // 创建通知
            let notificationRef = db.collection("notifications").document()
            batch.setData([
                "id": notificationRef.documentID,
                "eventId": eventId,
                "senderId": senderUserId,
                "receiverId": friendId,
                "type": "event_invitation",
                "createdAt": timestamp,
                "isRead": false,
                "status": "pending"
            ], forDocument: notificationRef)
        }
        
        try await batch.commit()
    }
    
    /// 获取用户的通知
    func fetchNotifications(for userId: String) async throws -> [NotificationEntry] {
        let snapshot = try await db.collection("notifications")
            .whereField("receiverId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> NotificationEntry? in
            let data = doc.data()
            
            guard let id = doc.documentID as String?,
                  let eventId = data["eventId"] as? Int,
                  let senderId = data["senderId"] as? String,
                  let receiverId = data["receiverId"] as? String,
                  let type = data["type"] as? String,
                  let isRead = data["isRead"] as? Bool,
                  let status = data["status"] as? String else {
                return nil
            }
            
            // 处理时间戳
            let createdAt: Date
            if let timestamp = data["createdAt"] as? Timestamp {
                createdAt = timestamp.dateValue()
            } else {
                createdAt = Date()
            }
            
            return NotificationEntry(
                id: id,
                eventId: eventId,
                senderId: senderId,
                receiverId: receiverId,
                type: type,
                createdAt: createdAt,
                isRead: isRead,
                status: status
            )
        }
    }
    
    /// 标记通知为已读
    func markNotificationAsRead(notificationId: String) async throws {
        try await db.collection("notifications")
            .document(notificationId)
            .updateData(["isRead": true])
    }
    
    /// 响应活动邀请
    func respondToInvitation(notificationId: String, status: String) async throws {
        // 更新通知状态
        try await db.collection("notifications")
            .document(notificationId)
            .updateData([
                "isRead": true,
                "status": status
            ])
        
        // 同时更新邀请记录
        let notificationSnapshot = try await db.collection("notifications")
            .document(notificationId)
            .getDocument()
        
        guard let notificationData = notificationSnapshot.data(),
              let eventId = notificationData["eventId"] as? Int,
              let senderId = notificationData["senderId"] as? String,
              let receiverId = notificationData["receiverId"] as? String else {
            throw NSError(domain: "EventManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "找不到通知信息"])
        }
        
        // 查找并更新对应的邀请记录
        let invitationsSnapshot = try await db.collection("event_invitations")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("senderId", isEqualTo: senderId)
            .whereField("receiverId", isEqualTo: receiverId)
            .getDocuments()
        
        for doc in invitationsSnapshot.documents {
            try await db.collection("event_invitations")
                .document(doc.documentID)
                .updateData(["status": status])
        }
    }
    
    // MARK: - 参与状态管理
    
    /// 获取用户对事件的参与状态
    /// - Returns: "shared"（未表态）、"joined"（参与）、"declined"（不参与），如果查询不到则返回 nil（视为未表态）
    func getParticipationStatus(eventId: Int, userId: String) async throws -> String? {
        let snapshot = try await db.collection("event_shares")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("receiverId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first,
              let status = document.data()["status"] as? String else {
            return nil // 查询不到视为未表态
        }
        
        return status
    }
    
    /// 更新或创建参与状态（Upsert）
    /// - Parameters:
    ///   - eventId: 事件ID
    ///   - userId: 用户ID
    ///   - status: 状态（"joined" 或 "declined"）
    ///   - creatorId: 创建者ID（用于索引/审计）
    ///   - source: 来源（"friend" | "group" | "direct" | "link"）
    func upsertParticipationStatus(
        eventId: Int,
        userId: String,
        status: String,
        creatorId: String,
        source: String
    ) async throws {
        // 先查找是否已存在记录
        let snapshot = try await db.collection("event_shares")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("receiverId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        
        let data: [String: Any] = [
            "eventId": eventId,
            "receiverId": userId,
            "creatorId": creatorId,
            "status": status,
            "source": source,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let existingDoc = snapshot.documents.first {
            // 更新现有记录
            try await existingDoc.reference.updateData(data)
        } else {
            // 创建新记录
            var newData = data
            newData["sharedAt"] = FieldValue.serverTimestamp()
            try await db.collection("event_shares").addDocument(data: newData)
        }
    }
}

// 通知条目结构
struct NotificationEntry: Identifiable {
    let id: String
    let eventId: Int
    let senderId: String
    let receiverId: String
    let type: String
    let createdAt: Date
    let isRead: Bool
    let status: String // 用于邀请状态
}
