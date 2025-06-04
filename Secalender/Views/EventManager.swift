//
//  EventManager.swift
//  Secalender
//
//  Created by linping on 2025/6/5.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift

class EventManager {
    static let shared = EventManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    /// 新增活动
    func addEvent(event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            var newEvent = event
            newEvent.createdAt = ISO8601DateFormatter().string(from: Date())
            newEvent.updatedAt = newEvent.createdAt
            
            _ = try db.collection("events").addDocument(from: newEvent) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 更新活动
    func updateEvent(event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let eventId = event.id else {
            completion(.failure(NSError(domain: "EventManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "活动ID不存在"])))
            return
        }
        
        do {
            var updatedEvent = event
            updatedEvent.updatedAt = ISO8601DateFormatter().string(from: Date())
            
            try db.collection("events").document(eventId).setData(from: updatedEvent, merge: true) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    /// 读取所有活动
    func fetchEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        db.collection("events").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else {
                let events = snapshot?.documents.compactMap {
                    try? $0.data(as: Event.self)
                } ?? []
                completion(.success(events))
            }
        }
    }
}
