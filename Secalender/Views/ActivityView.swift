//
//  ActivityView.swift
//  Secalender
//
//  Created by linping on 2024/6/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct ActivityView: View {
    @State private var activities: [Activity] = []
    
    var body: some View {
        NavigationView {
            List(activities) { activity in
                Text(activity.title)
            }
            .navigationTitle("活动")
            .onAppear {
                fetchActivities()
            }
        }
    }
    
    private func fetchActivities() {
        // 模拟获取活动数据
        activities = [
            Activity(id: UUID().uuidString, title: "活动 1"),
            Activity(id: UUID().uuidString, title: "活动 2")
        ]
    }
}

struct Activity: Identifiable {
    var id: String
    var title: String
}

#Preview {
    ActivityView()
}
