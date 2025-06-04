//
//  EventManager.swift
//  Secalender
//
//  Created by linping on 2024/7/9.
//

import FirebaseFirestore
import FirebaseFirestoreSwift

final class EventManager {
    
    static let shared = EventManager()
    private init() { }
    
    // 获取所有活动
    func fetchEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("events").getDocuments { (snapshot, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let events = documents.compactMap { (doc) -> Event? in
                try? doc.data(as: Event.self)
            }
            completion(.success(events))
        }
    }
    
    // 添加新活动
    func addEvent(event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        let db = Firestore.firestore()
        do {
            _ = try db.collection("events").addDocument(from: event)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // 更新活动
    func updateEvent(event: Event, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let eventID = event.id else {
            completion(.failure(URLError(.badURL)))
            return
        }
        let db = Firestore.firestore()
        do {
            try db.collection("events").document(eventID).setData(from: event, merge: true)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // 删除活动
    func deleteEvent(eventID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("events").document(eventID).delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // 获取单个活动
    func fetchEvent(eventID: String, completion: @escaping (Result<Event, Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("events").document(eventID).getDocument { (snapshot, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, let event = try? document.data(as: Event.self) else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            
            completion(.success(event))
        }
    }
}


