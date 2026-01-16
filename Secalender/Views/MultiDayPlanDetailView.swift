//
//  MultiDayPlanDetailView.swift
//  Secalender
//
//  多日行程详情页面
//

import SwiftUI

struct MultiDayPlanDetailView: View {
    let plan: PlanResult
    var onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: FirebaseUserManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 行程概览
                    planOverviewView
                    
                    // 每天的行程
                    daysListView
                    
                    // 假设和提示
                    assumptionsView
                }
                .padding()
            }
            .navigationTitle("行程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onAdd()
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    private var planOverviewView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("行程概览")
                .font(.headline)
            
            HStack {
                Label("\(plan.days.count)天", systemImage: "calendar")
                Spacer()
                if let firstDay = plan.days.first {
                    Text(formattedDate(from: firstDay.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var daysListView: some View {
        ForEach(plan.days.indices, id: \.self) { index in
            let day = plan.days[index]
            PlanDaySectionView(dayIndex: index + 1, day: day)
        }
    }
    
    @ViewBuilder
    private var assumptionsView: some View {
        if !plan.assumptions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("默认假设")
                    .font(.headline)
                ForEach(plan.assumptions, id: \.self) { assumption in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(assumption)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 辅助方法
    
    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
