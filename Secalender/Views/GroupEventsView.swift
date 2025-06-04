//
//  GroupEventsView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/29.
//

import SwiftUI

struct GroupEventsView: View {
    // 預留未來從 Firestore 或自建群組拉取資料的邏輯
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Spacer()
            Text("尚未加入任何社群活動")
                .foregroundColor(.gray)
                .font(.body)
            Spacer()
        }
    }
}
