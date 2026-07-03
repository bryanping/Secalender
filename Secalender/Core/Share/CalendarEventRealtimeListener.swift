//
//  CalendarEventRealtimeListener.swift
//  Secalender
//
//  好友與社群行程的即時監聽，5 分鐘快取期間仍能收到朋友/社群的變更
//

import Foundation
import FirebaseFirestore

extension Notification.Name {
    static let calendarEventsRealtimeUpdate = Notification.Name("CalendarEventsRealtimeUpdate")
}

/// 監聽好友、社群行程的 Firestore SnapshotListener，在有快取時不發 getDocuments，僅用 listener 接收變更
final class CalendarEventRealtimeListener {
    static let shared = CalendarEventRealtimeListener()
    private init() {}
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private let queue = DispatchQueue(label: "CalendarEventRealtimeListener.sync")
    
    /// 各來源最新快照：listener 回調時更新對應 bucket，再合併
    private var myEvents: [Event] = []
    private var friendEventsMap: [String: [Event]] = [:]
    private var groupEventsMap: [String: [Event]] = [:]
    
    private var currentMyId: String = ""
    
    /// 開始監聽。監聽會即時收到好友/社群的變更，並透過 Notification 通知 CalendarView
    func attachListeners(myId: String, friendIds: Set<String>, groupIds: Set<String>) {
        removeListeners()
        
        currentMyId = myId
        myEvents = []
        friendEventsMap = [:]
        groupEventsMap = [:]
        
        // 1. 監聽個人行程
        let myListener = db.collection("users")
            .document(myId)
            .collection("events")
            .addSnapshotListener { [weak self] snapshot, error in
                self?.handleMyEventsSnapshot(snapshot, error: error)
            }
        listeners.append(myListener)
        
        // 2. 監聽每位好友的公開行程
        for friendId in friendIds {
            let listener = db.collection("users")
                .document(friendId)
                .collection("events")
                .whereField("openChecked", isEqualTo: 1)
                .addSnapshotListener { [weak self] snapshot, error in
                    self?.handleFriendEventsSnapshot(friendId: friendId, snapshot: snapshot, error: error)
                }
            listeners.append(listener)
        }
        
        // 3. 監聽每個社群的行程
        for groupId in groupIds {
            let listener = db.collection("groups")
                .document(groupId)
                .collection("groupEvents")
                .addSnapshotListener { [weak self] snapshot, error in
                    self?.handleGroupEventsSnapshot(groupId: groupId, snapshot: snapshot, error: error)
                }
            listeners.append(listener)
        }
        
        print("📡 已附加 \(listeners.count) 個即時監聽（個人+好友+社群）")
    }
    
    /// 移除所有監聽，離開行事曆頁面時呼叫
    func removeListeners() {
        guard !listeners.isEmpty else { return }
        let count = listeners.count
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        print("📡 已移除 \(count) 個即時監聽")
    }
    
    private func handleMyEventsSnapshot(_ snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            print("⚠️ 個人行程 listener 錯誤: \(error.localizedDescription)")
            return
        }
        guard let snapshot = snapshot else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.myEvents = snapshot.documents.compactMap { EventManager.parseEventFromDocument($0) }
                .filter { $0.deleted != 1 }
            self.mergeAndNotify()
        }
    }
    
    private func handleFriendEventsSnapshot(friendId: String, snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            print("⚠️ 好友 \(friendId) 行程 listener 錯誤: \(error.localizedDescription)")
            return
        }
        guard let snapshot = snapshot else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.friendEventsMap[friendId] = snapshot.documents.compactMap { EventManager.parseEventFromDocument($0) }
                .filter { $0.deleted != 1 && $0.creatorOpenid == friendId }
            self.mergeAndNotify()
        }
    }
    
    private func handleGroupEventsSnapshot(groupId: String, snapshot: QuerySnapshot?, error: Error?) {
        if let error = error {
            print("⚠️ 社群 \(groupId) 行程 listener 錯誤: \(error.localizedDescription)")
            return
        }
        guard let snapshot = snapshot else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            self.groupEventsMap[groupId] = snapshot.documents.compactMap { EventManager.parseEventFromDocument($0) }
                .filter { $0.deleted != 1 }
            self.mergeAndNotify()
        }
    }
    
    private func mergeAndNotify() {
        var all: [Event] = []
        all.append(contentsOf: myEvents)
        for events in friendEventsMap.values {
            all.append(contentsOf: events)
        }
        for events in groupEventsMap.values {
            all.append(contentsOf: events)
        }
        
        var uniqueDict: [Int: Event] = [:]
        for event in all {
            if let id = event.id {
                uniqueDict[id] = event
            }
        }
        let merged = Array(uniqueDict.values)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .calendarEventsRealtimeUpdate,
                object: nil,
                userInfo: ["events": merged]
            )
        }
    }
}
