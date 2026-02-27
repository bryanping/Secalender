//
//  LevelBenefitsView.swift
//  Secalender
//
//  等級與權益：創作者等級、解鎖功能、權益說明
//

import SwiftUI

struct LevelBenefit: Identifiable {
    let id = UUID()
    let level: Int
    let name: String
    let benefits: [String]
    let isUnlocked: Bool
}

struct LevelBenefitsView: View {
    @State private var currentLevel: Int = 4
    @State private var expCurrent: Int = 1680
    @State private var expNeeded: Int = 2100
    
    private let benefits: [LevelBenefit] = [
        LevelBenefit(level: 1, name: "member.level_creator".localized(), benefits: ["member.benefit_basic".localized()], isUnlocked: true),
        LevelBenefit(level: 2, name: "member.level_creator".localized(), benefits: ["member.benefit_template".localized()], isUnlocked: true),
        LevelBenefit(level: 3, name: "member.level_creator".localized(), benefits: ["member.benefit_ai".localized()], isUnlocked: true),
        LevelBenefit(level: 4, name: "member.level_creator".localized(), benefits: ["member.benefit_market".localized()], isUnlocked: true),
        LevelBenefit(level: 5, name: "member.level_creator".localized(), benefits: ["member.benefit_bonus".localized()], isUnlocked: false)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 當前等級卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("member.level_badge".localized(with: currentLevel, ""))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    Text("member.exp_to_next".localized(with: currentLevel + 1, expNeeded - expCurrent))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    ProgressView(value: Double(expCurrent), total: Double(expNeeded))
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                }
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                
                // 等級權益列表
                VStack(alignment: .leading, spacing: 12) {
                    Text("member.level_benefits_title".localized())
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(benefits) { benefit in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(benefit.isUnlocked ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text("Lv\(benefit.level)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(benefit.isUnlocked ? .blue : .gray)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(benefit.benefits, id: \.self) { b in
                                    Text(b)
                                        .font(.subheadline)
                                        .foregroundColor(benefit.isUnlocked ? .primary : .secondary)
                                }
                            }
                            Spacer()
                            if benefit.isUnlocked {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("member.community_level".localized())
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        LevelBenefitsView()
    }
}
