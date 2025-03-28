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
        var newEvent = event
        let now = Date()
        if event.id == nil { // 新建事件才默认赋值
            newEvent.startDate = now
            newEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        }
        self.event = newEvent
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
