//
//  EventDetailViewModel.swift
//  Secalender
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

class EventDetailViewModel: ObservableObject {
    @Published var event: Event
    @Published var errorMessage: String? = nil
    @Published var isSaving: Bool = false

    init(event: Event = Event()) {
        self.event = event
    }

    func saveEvent(currentUserOpenId: String) async throws {
        isSaving = true
        errorMessage = nil

        if event.creatorOpenid.isEmpty {
            event.creatorOpenid = currentUserOpenId
        }

        // 注意：这个方法现在只用于后台同步到 Firebase
        // 本地缓存应该在调用此方法之前已经更新
        do {
            if let eventID = event.id {
                // 更新事件：只更新 Firebase，本地缓存应该已经更新
                try await EventManager.shared.updateEventInFirebaseOnly(event: event)
            } else {
                // 新建事件：添加到 Firebase，本地缓存应该已经添加
                try await EventManager.shared.addEventToFirebaseOnly(event: event)
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        isSaving = false
    }
}
