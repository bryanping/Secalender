//
//  TripPlanCard.swift
//  Secalender
//
//  行程卡片组件
//

import SwiftUI

struct TripPlanCard: View {
    let plan: PlanResult
    var onAddToCalendar: (() -> Void)? = nil
    var onViewDetails: (() -> Void)? = nil
    var onSaveToTemplate: (() -> Void)? = nil
    
    var numberOfDays: Int {
        plan.days.count
    }
    
    var isMultiDay: Bool {
        numberOfDays > 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：标题和天数
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let firstDay = plan.days.first,
                       let firstActivity = firstDay.blocks.first(where: { $0.type == .activity }) {
                        Text(firstActivity.location ?? "行程规划")
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        Text("行程规划")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 8) {
                        Label("\(numberOfDays)天", systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !plan.assumptions.isEmpty {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // 天数标签
                Text("\(numberOfDays)天")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isMultiDay ? Color.blue : Color.green)
                    .cornerRadius(12)
            }
            
            Divider()
            
            // 行程预览：显示前3个活动
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(plan.days.enumerated()), id: \.offset) { dayIndex, day in
                    if dayIndex < 2 || (dayIndex == 2 && !isMultiDay) {
                        let activities = day.blocks.filter { $0.type == .activity }
                        if let firstActivity = activities.first {
                            HStack(alignment: .top, spacing: 8) {
                                // 时间
                                Text(timeString(from: firstActivity.startTime))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                
                                // 活动信息
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(firstActivity.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    if let location = firstActivity.location {
                                        Text(location)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if isMultiDay && plan.days.count > 2 {
                    Text("...还有 \(plan.days.count - 2) 天的行程")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            // 假设提示
            if !plan.assumptions.isEmpty {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("包含 \(plan.assumptions.count) 个默认假设")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
            
            Divider()
            
            // 操作按钮
            HStack(spacing: 12) {
                // 保存到模板按钮
                Button(action: {
                    onSaveToTemplate?()
                }) {
                    HStack {
                        Image(systemName: "bookmark")
                        Text("保存")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                // 查看详情按钮
                Button(action: {
                    onViewDetails?()
                }) {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("详情")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 预览

struct TripPlanCard_Previews: PreviewProvider {
    static var previews: some View {
        let samplePlan = PlanResult(
            days: [
                DayPlan(
                    date: Date(),
                    blocks: [
                        TimeBlock(
                            type: .activity,
                            startTime: Date(),
                            endTime: Date().addingTimeInterval(3600),
                            title: "台北101观景台",
                            location: "台北市信义区",
                            isAnchor: false,
                            priority: 7,
                            description: "欣赏台北全景"
                        )
                    ]
                )
            ],
            assumptions: [],
            riskFlags: []
        )
        
        TripPlanCard(
            plan: samplePlan,
            onAddToCalendar: { print("添加到日历") },
            onViewDetails: { print("查看详情") }
        )
        .padding()
    }
}
