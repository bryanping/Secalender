//
//  Event.swift
//  Secalender
//
//  Created by linping on 2024/7/9.
//

import FirebaseFirestoreSwift
import Foundation

struct Event: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var creatorOpenid: String
    var createdAt: String
    var updatedAt: String
    var date: Date
    var startTime: String
    var openChecked: Bool
    var destination: String
    var startDate: Date
    var endDate: Date
    var sharedWithIds: [String] = []
    var participants: [String]  = []
    var location: String
    
    init(
        id: String? = nil,
        title: String = "",
        creatorOpenid: String = "",
        createdAt: String = "",
        updatedAt: String = "",
        date: Date = Date(),
        startTime: String = "",
        openChecked: Bool = false,
        destination: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
        sharedWithIds: [String] = [],
        participants: [String] = [],
        location: String = ""
        
    ) {
        self.id = id
        self.title = title
        self.creatorOpenid = creatorOpenid
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.date = date
        self.startTime = startTime
        self.openChecked = openChecked
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.sharedWithIds = sharedWithIds
        self.participants = participants
        self.location = location
    }
    
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm" // 根据实际格式调整
    return formatter
}()
