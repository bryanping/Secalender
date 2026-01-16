//
//  AchievementsView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//

import SwiftUI

struct Achievement: Identifiable {
    let id: UUID = UUID()
    var title: String
    var description: String
    var progress: Double
}

struct AchievementsView: View {
    @State private var achievements: [Achievement] = [
        Achievement(title: "連續早起七天",
                    description: "培養早睡早起的好習慣",
                    progress: 0.5),
        Achievement(title: "完成五套親子行程",
                    description: "與孩子共享愉快時光",
                    progress: 0.2),
        Achievement(title: "低碳出行十次",
                    description: "乘坐公共交通或騎乘自行車",
                    progress: 0.7)
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(achievements) { achievement in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(achievement.title).font(.headline)
                            Spacer()
                            Text(String(format: "%.0f%%", achievement.progress * 100))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Text(achievement.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ProgressView(value: achievement.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("成就與任務")
        }
    }
}


struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
