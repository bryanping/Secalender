//
//  TemplateDetailView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  模板市集的模板详情页面
//

import SwiftUI

struct TemplateDetailView: View {
    let template: StoreTemplate
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showingPurchaseAlert = false
    @State private var purchased = false
    @State private var showPlanDetail = false
    @State private var templatePlan: PlanResult? = nil
    @State private var isLoadingPlan = false

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
                Text(template.title)
                    .font(.title)
                    .bold()
                
                Text(template.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                
            HStack {
                ForEach(template.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
                
            Text(String(format: "NT$%.0f", template.price))
                .font(.title3)
                .foregroundColor(.green)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Button(action: {
                    // 真正的購買邏輯請整合您的支付方案
                    showingPurchaseAlert = true
                }) {
                    Text(purchased ? "已購買" : "購買模板")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(purchased ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(purchased)

                    if purchased {
                        Button(action: {
                            // 檢視行程：从 API 获取 PlanResult
                            loadTemplatePlan()
                        }) {
                            HStack {
                                if isLoadingPlan {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "eye.fill")
                                }
                                Text("檢視行程")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isLoadingPlan)

                Button(action: {
                    // 套用模板至行事曆的邏輯
                            if let plan = templatePlan {
                                applyPlanToCalendar(plan)
                            } else {
                                loadTemplatePlanAndApply()
                            }
                }) {
                    Text("套用至行事曆")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitle("模板詳情", displayMode: .inline)
        .sheet(isPresented: $showPlanDetail) {
            if let plan = templatePlan {
                NavigationView {
                    PlanDetailView(
                        plan: plan,
                        onEdit: { planToEdit in
                            templatePlan = planToEdit
                        },
                        onAddToCalendar: {
                            if let plan = templatePlan {
                                applyPlanToCalendar(plan)
                            }
                        },
                        onSaveToTemplate: { title in
                            if let plan = templatePlan {
                                savePlanToTemplate(plan, title: title)
                            }
                        }
                    )
                    .environmentObject(userManager)
                }
            }
        }
        .alert(isPresented: $showingPurchaseAlert) {
            if purchased {
                return Alert(title: Text("提示"),
                             message: Text("已將模板套用至您的行事曆。"),
                             dismissButton: .default(Text("確認")))
            } else {
                purchased = true
                return Alert(title: Text("購買成功"),
                             message: Text("感謝購買！您現在可以套用此模板。"),
                             dismissButton: .default(Text("好的")))
            }
        }
    }
    
    // MARK: - 方法
    
    /// 从 API 加载模板的 PlanResult（TODO: 需要实现实际的 API 调用）
    private func loadTemplatePlan() {
        isLoadingPlan = true
        
        // TODO: 从 API 获取 StoreTemplate 对应的 PlanResult
        // 目前使用模拟数据
        Task {
            // 模拟 API 调用延迟
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // TODO: 实际实现应从 API 获取
            // let plan = await fetchPlanFromAPI(templateId: template.id)
            
            await MainActor.run {
                isLoadingPlan = false
                // 暂时不设置 templatePlan，等待实际 API 实现
                // templatePlan = plan
                // showPlanDetail = true
            }
        }
    }
    
    /// 加载模板并应用到日历
    private func loadTemplatePlanAndApply() {
        loadTemplatePlan()
        // 加载完成后自动应用
    }
    
    /// 应用 PlanResult 到日历
    private func applyPlanToCalendar(_ plan: PlanResult) {
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            
            let items = PlanGenerator.shared.convertToScheduleItems(plan)
            
            for item in items {
                let startDate = combine(date: item.date, time: item.startTime)
                let endDate = combine(date: item.date, time: item.endTime)
                
                let dateString = dateFormatter.string(from: item.date)
                let startString = timeFormatter.string(from: startDate)
                let endString = timeFormatter.string(from: endDate)
                
                var event = Event()
                event.title = item.title
                event.creatorOpenid = userManager.userOpenId
                event.color = "#4285F4"
                event.date = dateString
                event.startTime = startString
                event.endTime = endString
                event.endDate = dateString
                event.destination = item.location
                event.mapObj = ""
                event.openChecked = 0
                event.personChecked = 0
                event.createTime = ""
                event.information = item.description
                event.groupId = nil
                
                do {
                    try await EventManager.shared.addEvent(event: event)
                } catch {
                    print("添加事件失敗：\(error)")
                }
            }
        }
    }
    
    /// 保存 PlanResult 到模板
    private func savePlanToTemplate(_ plan: PlanResult, title: String?) {
        let userId = userManager.userOpenId
        
        let templateTitle: String
        if let customTitle = title, !customTitle.isEmpty {
            templateTitle = customTitle
        } else if let destination = SavedTripTemplate.extractDestination(from: plan) {
            templateTitle = "\(destination) \(plan.days.count)天行程"
        } else {
            templateTitle = "行程模板 \(plan.days.count)天"
        }
        
        let destination = SavedTripTemplate.extractDestination(from: plan)
        
        let savedTemplate = SavedTripTemplate(
            title: templateTitle,
            plan: plan,
            savedDate: Date(),
            tags: [],
            destination: destination
        )
        
        TripTemplateManager.shared.saveTemplate(savedTemplate, for: userId)
    }
    
    /// 组合日期和时间
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: calendar.component(.second, from: time),
            of: date
        ) ?? date
    }
}
