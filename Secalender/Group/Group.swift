//
//  Group.swift
//  Secalender
//
//  Created by 林平 on 2025/8/10.
//

import FirebaseFirestoreSwift
import Foundation

struct Group: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var members: [String]           // 成員列表（openid）
    var owner: String               // 建立者
    var createdAt: Date?            // 建立時間

    init(id: String? = nil,
         name: String = "",
         description: String = "",
         members: [String] = [],
         owner: String = "",
         createdAt: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.members = members
        self.owner = owner
        self.createdAt = createdAt
    }
}
