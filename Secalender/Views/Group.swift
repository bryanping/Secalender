//
//  Group.swift
//  Secalender
//
//  Created by 林平 on 2025/6/7.
//

import Foundation
import FirebaseFirestoreSwift

struct Group: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var createdBy: String
    var memberIds: [String]
    var createdAt: Date

    init(
        id: String? = nil,
        name: String = "",
        createdBy: String = "",
        memberIds: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.memberIds = memberIds
        self.createdAt = createdAt
    }
}
