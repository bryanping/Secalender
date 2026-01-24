//
//  PlanDetailView.swift
//  Secalender
//
//  行程详情页面（统一处理单日和多日）
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct PlanDetailView: View {
    let plan: PlanResult
    var customTitle: String? = nil  // 用户自定义标题
    var onEdit: ((PlanResult) -> Void)? = nil
    var onAddToCalendar: (() -> Void)? = nil
    var onSaveToTemplate: ((String?) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil  // 关闭时的回调
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: FirebaseUserManager
    
    var body: some View {
        ZStack {
            groupedBackgroundColor
                .ignoresSafeArea()
            
            // 修复：直接检查数据，不使用 isReady 状态，避免一直转圈
            // 如果 plan.days 为空，显示空状态；否则直接显示内容
            if plan.days.isEmpty {
                // 空状态视图
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("行程数据无效")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // 头部：城市背景图 + 标题
                        headerView
                        
                        // 导航操作栏
                        actionBarView
                        
                        // 行程内容：垂直时间线
                        timelineContentView
                    }
                }
            }
        }
        #if os(iOS)
        // 修复：使用 navigationBarBackButtonHidden 而不是 navigationBarHidden，避免 toolbar 不显示
        .navigationBarBackButtonHidden(true)
        #endif
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // 先调用关闭回调，关闭整个 AIPlannerView
                    onDismiss?()
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        #endif
    }
    
    
    // MARK: - 头部视图
    
    private var headerView: some View {
        ZStack(alignment: .topLeading) {
            // 背景图（使用渐变模拟城市背景）
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.8),
                    Color.cyan.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)
            .overlay(
                // 模拟城市剪影效果
                Image(systemName: "building.2.fill")
                    .font(.system(size: 200))
                    .foregroundColor(.white.opacity(0.1))
                    .offset(x: 50, y: 50)
            )
            
            VStack(alignment: .leading, spacing: 12) {
                // VERIFIED TEMPLATE 徽章
                HStack {
                    Text("VERIFIED TEMPLATE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.9))
                        .cornerRadius(8)
                }
                .padding(.top, 60)
                .padding(.leading, 20)
                
                Spacer()
                
                // 标题和副标题
                VStack(alignment: .leading, spacing: 8) {
                    Text(planTitle)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                            Text("\(plan.days.count)天\(plan.days.count - 1)夜")
                                .font(.system(size: 16))
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                            Text(planDestination)
                                .font(.system(size: 16))
                        }
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
    
    // MARK: - 操作栏
    
    private var actionBarView: some View {
        HStack {
            Spacer()
            
            Button(action: {
                onEdit?(plan)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16))
                    Text("編輯行程")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(backgroundColor)
    }
    
    private var backgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemBackground)
        #else
        return Color.white
        #endif
    }
    
    private var groupedBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGroupedBackground)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
    
    private var gray6BackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray6)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    // MARK: - 时间线内容
    
    private var timelineContentView: some View {
        VStack(spacing: 0) {
            ForEach(plan.days.indices, id: \.self) { index in
                let day = plan.days[index]
                DayTimelineView(dayIndex: index + 1, day: day)
            }
        }
        .padding(.top, 20)
        .background(groupedBackgroundColor)
    }
    
    // MARK: - 计算属性
    
    private var planTitle: String {
        // 优先使用用户自定义标题
        if let customTitle = customTitle, !customTitle.isEmpty {
            return customTitle
        }
        // 否则使用默认标题
        let destination = extractDestination()
        return "\(destination)\(plan.days.count)日深度遊"
    }
    
    private var planDestination: String {
        let destination = extractDestination()
        if let country = extractCountry(from: destination) {
            return "\(country),\(destination)"
        }
        return destination
    }
    
    private func extractDestination() -> String {
        // 修复：扫描前 N 个 activity，找第一个有 location 的，提高成功率
        for day in plan.days {
            // 扫描该天的所有 activity blocks
            for block in day.blocks where block.type == .activity {
                if let location = block.location, !location.isEmpty {
                    // 尝试提取城市名（假设格式为 "城市" 或 "国家 - 城市"）
                    if location.contains(" - ") {
                        return String(location.split(separator: " - ").last ?? "")
                    }
                    return location
                }
            }
        }
        return "未知目的地"
    }
    
    private func extractCountry(from destination: String) -> String? {
        // 简单的国家映射
        let countryMap: [String: String] = [
            "東京": "日本",
            "京都": "日本",
            "大阪": "日本",
            "首爾": "韓國",
            "台北": "台灣",
            "曼谷": "泰國"
        ]
        
        for (city, country) in countryMap {
            if destination.contains(city) {
                return country
            }
        }
        return nil
    }
}

// MARK: - 单日时间线视图

struct DayTimelineView: View {
    let dayIndex: Int
    let day: DayPlan
    
    private var dayBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemBackground)
        #else
        return Color.white
        #endif
    }
    
    private var dayGray6BackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray6)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 日期标记（D1, D2...）
            HStack(alignment: .top, spacing: 16) {
                // D1/D2 圆形标记
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 50, height: 50)
                    
                    Text("D\(dayIndex)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // 日期标题
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(dayBackgroundColor)
            
            // 时间线：显示所有类型的 blocks，不只是 activity
            VStack(spacing: 0) {
                let sortedBlocks = day.blocks.sorted(by: { $0.startTime < $1.startTime })
                
                ForEach(Array(sortedBlocks.enumerated()), id: \.element.id) { index, block in
                    ActivityTimelineItemView(
                        block: block,
                        isLast: index == sortedBlocks.count - 1
                    )
                }
            }
            .padding(.leading, 20)
            .background(dayBackgroundColor)
        }
    }
    
    private var dayTitle: String {
        // 根据日期索引生成标题（可以从 DayPlan 中提取主题，这里使用默认值）
        let titles = [
            "抵達與城市初探",
            "潮流與傳統的交織",
            "文化深度體驗",
            "購物與美食探索",
            "告別與回憶"
        ]
        
        if dayIndex <= titles.count {
            return titles[dayIndex - 1]
        }
        return "第\(dayIndex)天"
    }
}

// MARK: - 活动时间线项目视图

struct ActivityTimelineItemView: View {
    let block: TimeBlock
    let isLast: Bool
    
    private var itemGray6BackgroundColor: Color {
        #if canImport(UIKit)
        return Color(UIColor.systemGray6)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 时间线连接线
            VStack(spacing: 0) {
                // 图标圆圈（根据类型使用不同颜色）
                ZStack {
                    Circle()
                        .fill(iconColorForBlock(block))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: iconForBlock(block))
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                // 连接线（如果不是最后一个）
                if !isLast {
                    Rectangle()
                        .fill(iconColorForBlock(block).opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 40)
            
            // 活动卡片
            VStack(alignment: .leading, spacing: 8) {
                // 时间和类型标签
                HStack(spacing: 8) {
                    Text(formattedTime(from: block.startTime))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColorForBlock(block))
                    
                    // 显示类型标签（对于非 activity 类型）
                    if block.type != .activity {
                        Text(typeLabelForBlock(block))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(iconColorForBlock(block).opacity(0.8))
                            .cornerRadius(4)
                    }
                }
                
                // 活动卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text(block.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let description = block.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(itemGray6BackgroundColor)
                .cornerRadius(12)
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 20)
    }
    
    // 根据 block 类型返回不同的颜色
    private func iconColorForBlock(_ block: TimeBlock) -> Color {
        switch block.type {
        case .activity:
            return .blue
        case .transit:
            return .orange
        case .buffer:
            return .gray
        case .flex:
            return .purple
        case .rest:
            return .green
        }
    }
    
    // 根据 block 类型返回标签文本
    private func typeLabelForBlock(_ block: TimeBlock) -> String {
        switch block.type {
        case .activity:
            return ""
        case .transit:
            return "交通"
        case .buffer:
            return "缓冲"
        case .flex:
            return "弹性"
        case .rest:
            return "休息"
        }
    }
    
    // 修复：基于 TimeBlockType 而不是 title 匹配，避免语言问题
    private func iconForBlock(_ block: TimeBlock) -> String {
        switch block.type {
        case .activity:
            // 对于 activity，可以根据 location 或 title 进一步细分
            let title = block.title.lowercased()
            if title.contains("餐廳") || title.contains("美食") || title.contains("拉麵") || title.contains("午餐") || title.contains("晚餐") {
                return "fork.knife"
            } else if title.contains("寺") || title.contains("神宮") || title.contains("神社") || title.contains("廟") {
                return "building.columns.fill"
            } else if title.contains("觀景") || title.contains("展望") || title.contains("塔") {
                return "binoculars.fill"
            } else {
                return "mappin.circle.fill"
            }
        case .transit:
            return "bus.fill"
        case .buffer:
            return "clock.fill"
        case .flex:
            return "clock.arrow.circlepath"
        case .rest:
            return "bed.double.fill"
        }
    }
    
    // 修复：使用单一方案（DateFormatter）并缓存，避免性能浪费和格式不一致
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }()
    
    private func formattedTime(from date: Date) -> String {
        // 使用缓存的 formatter，统一使用 24 小时制
        return Self.timeFormatter.string(from: date)
    }
}
