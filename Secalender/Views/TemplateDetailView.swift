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
    var creator: TemplateCreator? = nil
    var creatorTemplates: [StoreTemplate] = []  // 該創作者的全部模版（用於進入主頁）
    var isPurchased: Bool = false
    var isFollowing: Bool = false
    var onFollow: () -> Void = {}
    var onUnfollow: () -> Void = {}
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showingPurchaseAlert = false
    @State private var purchased: Bool
    @State private var showPlanDetail = false
    @State private var templatePlan: PlanResult? = nil
    @State private var isLoadingPlan = false

    init(
        template: StoreTemplate,
        creator: TemplateCreator? = nil,
        creatorTemplates: [StoreTemplate] = [],
        isPurchased: Bool = false,
        isFollowing: Bool = false,
        onFollow: @escaping () -> Void = {},
        onUnfollow: @escaping () -> Void = {}
    ) {
        self.template = template
        self.creator = creator
        self.creatorTemplates = creatorTemplates
        self.isPurchased = isPurchased
        self.isFollowing = isFollowing
        self.onFollow = onFollow
        self.onUnfollow = onUnfollow
        _purchased = State(initialValue: isPurchased || template.price == 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 封面圖區域
                coverSection

                Text(template.title)
                    .font(.title2)
                    .bold()
                
                if let creator = creator {
                    creatorRow(creator)
                }
                
                Text(template.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // 標籤、評分、天數、購買數
                metaSection
                
                // 價格
                priceSection

                Spacer(minLength: 16)

                // 操作按鈕
                VStack(spacing: 12) {
                // 開發期間：價格為0的模板可以直接添加到我的模板
                if template.price == 0 {
                    Button(action: {
                        // 直接添加到我的模板（開發期間免費使用）
                        addToMyTemplates()
                    }) {
                        Text("template_detail.add_to_my_templates".localized())
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                } else {
                    Button(action: {
                        // 真正的購買邏輯請整合您的支付方案
                        showingPurchaseAlert = true
                    }) {
                        Text(purchased ? "template_detail.purchased".localized() : "template_detail.buy_template".localized())
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(purchased ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(purchased)
                }

                // 如果已購買或價格為0（開發期間免費），顯示檢視和套用按鈕
                if purchased || template.price == 0 {
                    Button(action: {
                        // 檢視行程：从 API 获取 PlanResult
                        Task {
                            await loadTemplatePlan()
                        }
                    }) {
                        HStack {
                            if isLoadingPlan {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "eye.fill")
                            }
                            Text("template_detail.view_trip".localized())
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
                            Task {
                                await loadTemplatePlanAndApply()
                            }
                        }
                    }) {
                        Text("template_detail.apply_to_calendar".localized())
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
        .navigationBarTitle("template_detail.title".localized(), displayMode: .inline)
        .fullScreenCover(isPresented: $showPlanDetail) {
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
                return Alert(title: Text("template_detail.tip".localized()),
                             message: Text("template_detail.applied".localized()),
                             dismissButton: .default(Text("template_detail.confirm".localized())))
            } else {
                purchased = true
                TemplatePurchaseManager.shared.markAsPurchased(templateId: template.id, for: userManager.userOpenId)
                return Alert(title: Text("template_detail.purchase_success".localized()),
                             message: Text("template_detail.thanks_purchase".localized()),
                             dismissButton: .default(Text("template_detail.ok".localized())))
            }
        }
    }
    
    // MARK: - UI Sections
    
    private var coverSection: some View {
        Group {
            if let urlString = template.coverImageURL, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure, .empty: detailGradientPlaceholder
                    @unknown default: detailGradientPlaceholder
                    }
                }
            } else {
                detailGradientPlaceholder
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipped()
        .cornerRadius(12)
    }
    
    private func creatorRow(_ creator: TemplateCreator) -> some View {
        NavigationLink(destination: creatorProfileDestination(creator)) {
            HStack(spacing: 12) {
                avatarPlaceholderView(creator)
                VStack(alignment: .leading, spacing: 2) {
                    Text(creator.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("creator.templates_count".localized(with: creator.templateCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    if isFollowing { onUnfollow() } else { onFollow() }
                }) {
                    Text(isFollowing ? "creator.following".localized() : "creator.follow".localized())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isFollowing ? .secondary : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue.opacity(0.15))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private func avatarPlaceholderView(_ creator: TemplateCreator) -> some View {
        Text(creator.name.prefix(1))
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }
    
    @ViewBuilder
    private func creatorProfileDestination(_ creator: TemplateCreator) -> some View {
        CreatorProfileView(
            creator: creator,
            templates: creatorTemplates,
            isFollowing: isFollowing,
            isPurchased: { t in
                t.id == template.id ? isPurchased : TemplatePurchaseManager.shared.isPurchased(templateId: t.id, for: userManager.userOpenId)
            },
            onFollow: onFollow,
            onUnfollow: onUnfollow
        )
        .environmentObject(userManager)
    }
    
    private var detailGradientPlaceholder: some View {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.6),
                Color.purple.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
        )
    }
    
    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ForEach(template.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            HStack(spacing: 16) {
                if let rating = template.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Label("\(template.daysCount) " + "template_detail.days".localized(), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if template.purchaseCount > 0 {
                    Label("\(template.purchaseCount) " + "template_detail.purchases".localized(), systemImage: "person.2.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
    
    private var priceSection: some View {
        Group {
            if template.price == 0 {
                Text("template_detail.free".localized())
                    .font(.title3)
                    .foregroundColor(.blue)
            } else {
                Text("template_store.price_format".localized(with: template.price))
                    .font(.title3)
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - 方法
    
    /// 添加到我的模板（免費模板直接添加）
    private func addToMyTemplates() {
        // 開發期間：價格為0的模板可以直接添加到我的模板
        // 這裡需要從API獲取完整的PlanResult，然後保存到本地模板
        Task {
            await loadTemplatePlan()
            
            // 如果成功加載了PlanResult，保存到我的模板
            if let plan = templatePlan {
                await MainActor.run {
                    savePlanToTemplate(plan, title: template.title)
                    TemplatePurchaseManager.shared.markAsPurchased(templateId: template.id, for: userManager.userOpenId)
                    showingPurchaseAlert = true
                    purchased = true
                }
            }
        }
    }
    
    /// 从 API 加载模板的 PlanResult
    private func loadTemplatePlan() async {
        await MainActor.run {
            isLoadingPlan = true
        }
        
        // TODO: 从 API 获取 StoreTemplate 对应的 PlanResult
        // 目前使用模拟数据生成一个基本的PlanResult
        // 实际实现应从 API 获取: /api/templates/{templateId}/content
        
        // 模拟 API 调用延迟
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // 生成一个基本的PlanResult（开发期间使用模拟数据）
        let mockPlan = generateMockPlanResult(for: template)
        
        await MainActor.run {
            isLoadingPlan = false
            templatePlan = mockPlan
            showPlanDetail = true
        }
    }
    
    /// 生成模拟的PlanResult（开发期间使用）
    private func generateMockPlanResult(for template: StoreTemplate) -> PlanResult {
        let today = Date()
        var dayPlans: [DayPlan] = []
        
        // 根据模板标题推断天数（简单处理）
        let daysCount = template.daysCount > 0 ? template.daysCount : (extractDaysFromTitle(template.title) ?? 3)
        
        for dayIndex in 0..<daysCount {
            let date = Calendar.current.date(byAdding: .day, value: dayIndex, to: today) ?? today
            var blocks: [TimeBlock] = []
            
            // 为每一天生成2-3个活动
            let activitiesPerDay = 2
            for activityIndex in 0..<activitiesPerDay {
                let startHour = 9 + activityIndex * 3
                let startDate = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: date) ?? date
                let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate) ?? startDate
                
                var block = TimeBlock(
                    type: .activity,
                    startTime: startDate,
                    endTime: endDate,
                    title: "\(template.title) - 活動 \(activityIndex + 1)",
                    location: template.title,
                    isAnchor: activityIndex == 0,
                    priority: 8,
                    description: template.description
                )
                blocks.append(block)
            }
            
            let dayPlan = DayPlan(date: date, blocks: blocks)
            dayPlans.append(dayPlan)
        }
        
        return PlanResult(
            days: dayPlans,
            assumptions: [
                "建議提前預訂熱門景點門票",
                "預留彈性時間應對突發情況"
            ],
            riskFlags: [
                "注意景點的開放時間和節假日安排",
                "建議攜帶地圖或使用導航應用"
            ]
        )
    }
    
    /// 从标题中提取天数
    private func extractDaysFromTitle(_ title: String) -> Int? {
        // 简单匹配：寻找"X日"或"X天"的模式
        let patterns = [
            "([0-9]+)日",
            "([0-9]+)天"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: title, options: [], range: NSRange(location: 0, length: title.utf16.count)),
               let range = Range(match.range(at: 1), in: title),
               let days = Int(title[range]) {
                return days
            }
        }
        
        return nil
    }
    
    /// 加载模板并应用到日历
    private func loadTemplatePlanAndApply() async {
        await loadTemplatePlan()
        // 加载完成后自动应用
        if let plan = templatePlan {
            applyPlanToCalendar(plan)
        }
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
        
        // 保存模板（不自动同步到行事历，用户需要在 PlanDetailView 中选择"加入行程"）
        TripTemplateManager.shared.saveTemplate(savedTemplate, for: userId, syncToAppleCalendar: false)
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
