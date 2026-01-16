//
//  PlanEditView.swift
//  Secalender
//
//  行程编辑页面（编辑开始日期、更换行程）
//

import SwiftUI

struct PlanEditView: View {
    @State var plan: PlanResult
    var onSave: ((PlanResult) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: FirebaseUserManager
    
    @State private var selectedStartDate: Date
    @State private var showRegeneratePlan = false
    @State private var isRegenerating = false
    
    init(plan: PlanResult, onSave: ((PlanResult) -> Void)? = nil) {
        self.plan = plan
        self.onSave = onSave
        // 初始化开始日期（使用第一个行程的日期）
        _selectedStartDate = State(initialValue: plan.days.first?.date ?? Date())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("行程信息")) {
                    // 天数显示
                    HStack {
                        Text("天数")
                        Spacer()
                        Text("\(plan.days.count)天")
                            .foregroundColor(.secondary)
                    }
                    
                    // 开始日期选择
                    DatePicker("旅行开始日期", selection: $selectedStartDate, displayedComponents: .date)
                }
                
                Section(header: Text("操作")) {
                    // 更新日期
                    Button(action: {
                        updatePlanDates()
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("更新日期")
                        }
                        .foregroundColor(.orange)
                    }
                    
                    // 重新生成行程
                    Button(action: {
                        showRegeneratePlan = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("重新生成行程")
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(isRegenerating)
                    
                    if isRegenerating {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("正在重新生成...")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                
                // 预览修改后的行程
                Section(header: Text("行程预览")) {
                    ForEach(plan.days.indices, id: \.self) { index in
                        let day = plan.days[index]
                        NavigationLink(destination: PlanDaySectionView(dayIndex: index + 1, day: day)) {
                            HStack {
                                Text("第\(index + 1)天")
                                    .font(.headline)
                                Spacer()
                                Text(formattedDate(from: day.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("编辑行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave?(plan)
                        dismiss()
                    }
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                }
            }
            .alert("重新生成行程", isPresented: $showRegeneratePlan) {
                Button("取消", role: .cancel) { }
                Button("确定", role: .destructive) {
                    Task {
                        await regeneratePlan()
                    }
                }
            } message: {
                Text("这将使用AI重新生成行程，是否继续？")
            }
        }
    }
    
    // MARK: - 操作
    
    /// 更新行程日期
    private func updatePlanDates() {
        let calendar = Calendar.current
        var updatedDays: [DayPlan] = []
        
        // 计算日期偏移
        guard let firstDay = plan.days.first else { return }
        let originalStartDate = firstDay.date
        let daysOffset = calendar.dateComponents([.day], from: originalStartDate, to: selectedStartDate).day ?? 0
        
        // 更新每一天的日期
        for day in plan.days {
            if let newDate = calendar.date(byAdding: .day, value: daysOffset, to: day.date) {
                var updatedDay = day
                updatedDay.date = newDate
                // 更新每个 block 的日期
                var updatedBlocks: [TimeBlock] = []
                for block in day.blocks {
                    var updatedBlock = block
                    if let newStartTime = calendar.date(byAdding: .day, value: daysOffset, to: block.startTime),
                       let newEndTime = calendar.date(byAdding: .day, value: daysOffset, to: block.endTime) {
                        updatedBlock.startTime = newStartTime
                        updatedBlock.endTime = newEndTime
                    }
                    updatedBlocks.append(updatedBlock)
                }
                updatedDay.blocks = updatedBlocks
                updatedDays.append(updatedDay)
            } else {
                updatedDays.append(day)
            }
        }
        
        var updatedPlan = plan
        updatedPlan.days = updatedDays
        plan = updatedPlan
    }
    
    /// 重新生成行程
    private func regeneratePlan() async {
        isRegenerating = true
        
        // 从原行程中提取信息
        guard let firstDay = plan.days.first,
              let firstActivity = firstDay.blocks.first(where: { $0.type == .activity }) else {
            isRegenerating = false
            return
        }
        
        let destination = firstActivity.location ?? ""
        let numberOfDays = plan.days.count
        
        do {
            // 使用AI重新生成行程
            let calendar = Calendar.current
            let startDate = selectedStartDate
            let endDate = calendar.date(byAdding: .day, value: numberOfDays - 1, to: startDate) ?? startDate
            
            // 这里需要从原始输入中提取兴趣标签等信息
            // 暂时使用默认值
            let aiPlan = try await AITripGenerator.shared.generateAIItinerary(
                destination: destination,
                startDate: startDate,
                endDate: endDate,
                durationDays: numberOfDays,
                interestTags: [], // TODO: 从原行程中提取
                pace: .moderate,
                walkingLevel: nil,
                transportPreference: nil
            )
            
            // 转换为PlanResult
            var extractedSlots = ExtractedSlots()
            extractedSlots.destination = SlotInfo(value: destination, confidence: 1.0)
            let newPlan = try AITripGenerator.shared.convertToPlanResult(aiPlan, slots: extractedSlots)
            
            // 更新plan
            plan = newPlan
            
        } catch {
            print("❌ 重新生成行程失败: \(error.localizedDescription)")
        }
        
        isRegenerating = false
    }
    
    // MARK: - 辅助方法
    
    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
