import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/linping/Desktop/活動歷/MyFirstProgram/Secalender/Secalender/Views/ActivityView.swift", line: 1)
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
            .navigationTitle(__designTimeString("#3034_0", fallback: "活动"))
            .onAppear {
                fetchActivities()
            }
        }
    }
    
    private func fetchActivities() {
        // 模拟获取活动数据
        activities = [
            Activity(id: UUID().uuidString, title: __designTimeString("#3034_1", fallback: "活动 1")),
            Activity(id: UUID().uuidString, title: __designTimeString("#3034_2", fallback: "活动 2"))
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
