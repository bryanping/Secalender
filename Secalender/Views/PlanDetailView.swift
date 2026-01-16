//
//  PlanDetailView.swift
//  Secalender
//
//  行程详情页面（统一处理单日和多日）
//

import SwiftUI

struct PlanDetailView: View {
    let plan: PlanResult
    var onEdit: ((PlanResult) -> Void)? = nil
    var onAddToCalendar: (() -> Void)? = nil
    var onSaveToTemplate: ((String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showSaveTemplateAlert = false
    @State private var templateTitle = ""
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // 编辑按钮
                        Button(action: {
                            onEdit?(plan)
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.orange)
                        }
                        
                        // 保存到模板按钮
                        Button(action: {
                            showSaveTemplateAlert = true
                        }) {
                            Image(systemName: "bookmark")
                                .foregroundColor(.blue)
                        }
                        
                        // 添加到日历按钮
                        Button("加入行程") {
                            onAddToCalendar?()
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .alert("保存到行程模板", isPresented: $showSaveTemplateAlert) {
                TextField("请输入模板名称（可选）", text: $templateTitle)
                    .autocapitalization(.words)
                Button("取消", role: .cancel) {
                    templateTitle = ""
                }
                Button("保存") {
                    saveToTemplate()
                }
            } message: {
                Text("为这个行程模板起个名字（可选，留空将使用默认名称）")
            }
        }
    }
    
    // MARK: - 方法
    
    private func saveToTemplate() {
        let title = templateTitle.isEmpty ? nil : templateTitle
        onSaveToTemplate?(title)
        templateTitle = ""
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
