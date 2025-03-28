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
    var date: Date
    var startTime: String
    var openChecked: Bool
    var destination: String
    var startDate: Date
    var endDate: Date
    
    
    init(id: String? = nil, title: String = "", creatorOpenid: String = "", date: Date = Date(), startTime: String = "", openChecked: Bool = false, destination: String = "", startDate: Date = Date(), endDate: Date = Date()) {
        self.id = id
        self.title = title
        self.creatorOpenid = creatorOpenid
        self.date = date
        self.startTime = startTime
        self.openChecked = openChecked
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm" // 根据实际格式调整
    return formatter
}()
