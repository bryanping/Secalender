//
//  ScheduleItem.swift
//  Secalender
//
//  Created by 林平 on 2025/8/10.
//

import Foundation

struct ScheduleItem: Identifiable {
    let id = UUID()
    var title: String
    var date: Date
    var startTime: Date
    var endTime: Date
    var location: String
    var description: String
}
