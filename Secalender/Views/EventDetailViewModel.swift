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

        do {
            if let eventID = event.id {
                try await EventManager.shared.updateEvent(event: event)
            } else {
                try await EventManager.shared.addEvent(event: event)
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        isSaving = false
    }
}
