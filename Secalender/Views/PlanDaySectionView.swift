//
//  PlanDaySectionView.swift
//  Secalender
//
//  多日行程中的单日行程视图组件
//

import SwiftUI

struct PlanDaySectionView: View {
    let dayIndex: Int
    let day: DayPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 日期标题
            dayHeaderView
            
            Divider()
            
            // 活动列表
            activitiesListView
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 子视图
    
    private var dayHeaderView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("第\(dayIndex)天")
                    .font(.headline)
                Spacer()
                Text(formattedDate(from: day.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            // 如果有主题和关键词，显示在这里（需要从 DayPlan 传递）
        }
    }
    
    private var activitiesListView: some View {
        let sortedBlocks = day.blocks.sorted(by: { $0.startTime < $1.startTime })
        let activityBlocks = sortedBlocks.filter { $0.type == .activity }
        
        return ForEach(activityBlocks) { block in
            ActivityRowView(block: block)
        }
    }
    
    // MARK: - 辅助方法
    
    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
}

struct ActivityRowView: View {
    let block: TimeBlock
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间列
            timeColumnView
            
            // 活动信息列
            activityInfoView
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 子视图
    
    private var timeColumnView: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(formattedTime(from: block.startTime))
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(formattedTime(from: block.endTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 70)
    }
    
    private var activityInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(block.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            locationView
            
            descriptionView
        }
    }
    
    @ViewBuilder
    private var locationView: some View {
        if let location = block.location {
            HStack {
                Image(systemName: "location.fill")
                    .font(.caption2)
                Text(location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var descriptionView: some View {
        if let description = block.description {
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)  // 不限制行数，显示完整描述（包括思路说明）
                .fixedSize(horizontal: false, vertical: true)  // 允许垂直扩展
        }
    }
    
    // MARK: - 辅助方法
    
    private func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
