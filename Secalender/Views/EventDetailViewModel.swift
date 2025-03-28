//
//  EventDetailViewModel.swift
//  Secalender
//
//  Created by linping on 2024/7/9.
//

import SwiftUI

class EventDetailViewModel: ObservableObject {
    @Published var event: Event
    
    init(event: Event = Event()) {
        self.event = event
    }
    
    func loadEvent() {
        // 加载活动的详细信息
    }
    
    func saveEvent(completion: @escaping (Bool) -> Void) {
        if event.creatorOpenid.isEmpty {
            event.creatorOpenid = "current_user_openid" // 替换为实际当前用户的 OpenID
        }
        
        if let eventID = event.id {
            EventManager.shared.updateEvent(event: event) { result in
                switch result {
                case .success():
                    completion(true)
                case .failure(let error):
                    print(error.localizedDescription)
                    completion(false)
                }
            }
        } else {
            EventManager.shared.addEvent(event: event) { result in
                switch result {
                case .success():
                    completion(true)
                case .failure(let error):
                    print(error.localizedDescription)
                    completion(false)
                }
            }
        }
    }
}
