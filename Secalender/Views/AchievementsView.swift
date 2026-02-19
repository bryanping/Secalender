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
        Achievement(title: "achievements.early_bird.title".localized(),
                    description: "achievements.early_bird.description".localized(),
                    progress: 0.5),
        Achievement(title: "achievements.family_trips.title".localized(),
                    description: "achievements.family_trips.description".localized(),
                    progress: 0.2),
        Achievement(title: "achievements.low_carbon.title".localized(),
                    description: "achievements.low_carbon.description".localized(),
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
            .navigationTitle("member.achievements_tasks".localized())
        }
    }
}


struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
