import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum TemplateFilterType: String, CaseIterable {
    case myCreations = "my_creations"
    case purchased = "purchased"
    case friendShares = "friend_shares"
    
    @MainActor
    var localizedDisplayName: String {
        switch self {
        case .myCreations: return "my_templates.filter.my_creations".localized()
        case .purchased: return "my_templates.filter.purchased".localized()
        case .friendShares: return "my_templates.filter.friend_shares".localized()
        }
    }
}

// 统一的 Sheet 状态管理，避免两个 sheet 切换时的状态错乱
enum TemplateSheetType: Identifiable {
    case planDetail(SavedTripTemplate)
    case planEdit(plan: PlanResult, template: SavedTripTemplate)
    
    var id: UUID {
        switch self {
        case .planDetail(let template):
            return template.id
        case .planEdit(_, let template):
            // 使用 template.id 作为编辑页的 id（每个 template 在同一时间只会有一个编辑状态）
            return template.id
        }
    }
}

struct MyTemplatesView: View {
    @EnvironmentObject var userManager: FirebaseUserManager

    @StateObject private var vm = MyTemplatesViewModel() //修改内容：用 ViewModel 承载状态，避免 Debug 卡断点

    @State private var searchText: String = ""
    @State private var selectedFilter: TemplateFilterType = .myCreations
    @State private var activeSheet: TemplateSheetType? = nil  // 统一的 sheet 状态
    @State private var showDeleteConfirmation = false
    @State private var templateToDelete: SavedTripTemplate? = nil
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    // 多行程检视相关状态
    @State private var showMultiEventView = false
    @State private var savedEventIds: [Int] = []
    @State private var allEvents: [Event] = []  // 用于 MultiEventView 的事件列表
    @State private var currentTemplate: SavedTripTemplate? = nil  // 当前打开的模版（用于返回）

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                filterButtons
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                if vm.isLoading && vm.savedTemplates.isEmpty {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if vm.filteredTemplates.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(vm.filteredTemplates) { template in
                            templateCard(template)
                        }

                        if !vm.filteredTemplates.isEmpty {
                            bottomInspirationSection
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        .fullScreenCover(item: $activeSheet) { sheetType in
            Group {
                switch sheetType {
                case .planDetail(let template):
                    NavigationView {
                        PlanDetailView(
                            plan: template.plan,
                            customTitle: template.title,  // 传递模板标题（来自"此行的主题"）
                            onEdit: { planToEdit in
                                // 编辑功能：切换到 PlanEditView
                                activeSheet = .planEdit(plan: planToEdit, template: template)
                            },
                            onAddToCalendar: nil,
                            onSaveToTemplate: nil,
                            onDismiss: {
                                activeSheet = nil
                            }
                        )
                        .environmentObject(userManager)
                    }
                case .planEdit(let plan, let template):
                    PlanEditView(
                        plan: plan,
                        customTitle: template.title,  // 使用模板保存的标题（来自用户填写的"此行的主題"）
                        onSaveToCalendar: { eventIds in
                            // 保存到日历后，导航到多行程检视页面
                            savedEventIds = eventIds
                            currentTemplate = template
                            activeSheet = nil
                            // 加载事件列表
                            Task {
                                await loadEventsForMultiView()
                                await MainActor.run {
                                    showMultiEventView = true
                                }
                            }
                        },
                        onSaveToTemplate: { editedPlan, title in
                            // 修复：使用编辑后的 PlanResult，而不是进入编辑页前的 plan
                            var updatedTemplate = template
                            updatedTemplate.plan = editedPlan  // 使用编辑后的 plan
                            if let newTitle = title, !newTitle.isEmpty {
                                updatedTemplate.title = newTitle
                            }
                            TripTemplateManager.shared.updateTemplate(updatedTemplate, for: userManager.userOpenId)
                            // 重新加载模板列表
                            vm.reload(userId: userManager.userOpenId)
                            activeSheet = nil
                        },
                        onDismiss: {
                            // 退出编辑页面，返回详情页
                            activeSheet = .planDetail(template)
                        }
                    )
                    .environmentObject(userManager)
                }
            }
        }
        .sheet(isPresented: $showMultiEventView) {
            NavigationView {
                MultiEventView(
                    eventIds: savedEventIds,
                    allEvents: $allEvents,
                    source: .template,  // 标识从行程模版打开
                    onComplete: {
                        // 完成操作后不关闭页面，保持在多行程检视页面
                    },
                    onRefreshEvents: {
                        // 刷新事件列表
                        await loadEventsForMultiView()
                    },
                    onDismiss: nil,  // 从模版打开时不使用 onDismiss
                    onBackToTemplate: {
                        // 返回到行程模版（PlanDetailView）
                        showMultiEventView = false
                        // 重新打开详情页
                        if let template = currentTemplate {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                activeSheet = .planDetail(template)
                            }
                        }
                    }
                )
                .environmentObject(userManager)
            }
        }
        //修改内容：只依赖 userOpenId，一次加载；避免 onAppear/onChange/task 互撞
        .task(id: userManager.userOpenId) {
            let uid = userManager.userOpenId
            guard !uid.isEmpty else { return }
            vm.load(userId: uid)
        }
        .alert("確認刪除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {
                templateToDelete = nil
            }
            Button("刪除", role: .destructive) {
                if let template = templateToDelete {
                    deleteTemplate(template)
                }
            }
        } message: {
            if let template = templateToDelete {
                Text("my_templates.delete_confirmation".localized(with: template.title))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    // MARK: - 删除和分享功能
    
    private func deleteTemplate(_ template: SavedTripTemplate) {
        TripTemplateManager.shared.deleteTemplate(template.id, for: userManager.userOpenId)
        vm.reload(userId: userManager.userOpenId)
        templateToDelete = nil
    }
    
    private func shareTemplate(_ template: SavedTripTemplate) {
        // 构建分享文本
        var shareText = "\(template.title)\n\n"
        
        if let destination = template.destination {
            shareText += "目的地：\(destination)\n"
        }
        
        shareText += "行程天数：\(template.plan.days.count)天\n\n"
        
        // 添加每天的行程
        for (dayIndex, day) in template.plan.days.enumerated() {
            shareText += "第\(dayIndex + 1)天：\n"
            
            let activities = day.blocks.filter { $0.type == .activity }
            for (index, activity) in activities.enumerated() {
                let timeString = Self.timeFormatter.string(from: activity.startTime)
                shareText += "\(timeString) - \(activity.title)"
                if let location = activity.location {
                    shareText += " (\(location))"
                }
                shareText += "\n"
            }
            
            if dayIndex < template.plan.days.count - 1 {
                shareText += "\n"
            }
        }
        
        shareItems = [shareText]
        showShareSheet = true
    }

    // MARK: - 搜索栏（你原来的保持）
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))

            TextField("搜尋行程模板...", text: Binding(
                get: { searchText },
                set: { newValue in
                    searchText = newValue
                    vm.searchText = newValue
                }
            ))
                .textFieldStyle(.plain)
                .font(.system(size: 15))

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    vm.searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }

            Button(action: {
                // TODO
            }) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - 筛选按钮（你原来的保持）
    private var filterButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TemplateFilterType.allCases, id: \.self) { filterType in
                    Button(action: {
                        selectedFilter = filterType
                        vm.selectedFilterRawValue = filterType.rawValue
                    }) {
                        Text(filterType.localizedDisplayName)
                            .font(.system(size: 14, weight: selectedFilter == filterType ? .semibold : .medium))
                            .foregroundColor(selectedFilter == filterType ? .blue : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filterType
                                ? Color.blue.opacity(0.15)
                                : Color(.systemBackground)
                            )
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedFilter == filterType ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - filteredTemplates 已移到 ViewModel 中，避免每次 body 计算都重新过滤和排序

    // MARK: - 模板卡片
    private func templateCard(_ template: SavedTripTemplate) -> some View {
        Button(action: {
            // 验证 plan 数据完整性
            guard !template.plan.days.isEmpty else {
                // 如果数据无效，不显示
                return
            }
            // 直接使用 template 驱动 sheet，避免状态不同步导致的空白
            activeSheet = .planDetail(template)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // 头部：标题和天数
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        HStack(spacing: 8) {
                            if let destination = template.destination {
                                let countryCity = formatCountryCity(from: destination)
                                Label(countryCity, systemImage: "mappin.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Label("my_templates.days".localized(with: template.plan.days.count), systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 操作菜单按钮
                    Menu {
                        Button(role: .destructive, action: {
                            templateToDelete = template
                            showDeleteConfirmation = true
                        }) {
                            Label("my_templates.delete".localized(), systemImage: "trash")
                        }
                        
                        Button(action: {
                            shareTemplate(template)
                        }) {
                            Label("my_templates.share".localized(), systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, weight: .medium))
                            .padding(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 评分标签
                    ratingStarsView(rating: template.rating)
                }
                
                // 标签和日期
                if !template.tags.isEmpty {
                    Divider()
                    
                    HStack {
                        ForEach(template.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Text(formatDate(template.savedDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 加载事件列表（用于 MultiEventView）
    private func loadEventsForMultiView() async {
        guard !userManager.userOpenId.isEmpty else { return }
        
        // 从本地缓存加载事件
        let cachedEvents = EventCacheManager.shared.loadEvents(for: userManager.userOpenId)
        await MainActor.run {
            allEvents = cachedEvents.filter { $0.deleted != 1 }
        }
        
        // 后台同步 Firebase
        Task {
            do {
                try await EventManager.shared.fetchEvents()
                let updatedEvents = EventCacheManager.shared.loadEvents(for: userManager.userOpenId)
                await MainActor.run {
                    allEvents = updatedEvents.filter { $0.deleted != 1 }
                }
            } catch {
                print("⚠️ 加载事件失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 辅助方法
    // 缓存 DateFormatter 以提高性能，避免每次渲染都创建新实例
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }()
    
    private func timeString(from date: Date) -> String {
        return Self.timeFormatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        return Self.dateFormatter.string(from: date)
    }
    
    /// 格式化目的地为国家-城市格式
    private func formatCountryCity(from destination: String) -> String {
        // 如果已经是"国家 - 城市"格式，直接返回
        if destination.contains(" - ") {
            return destination
        }
        
        // 尝试从城市名推断国家
        let countryMap: [String: String] = [
            "東京": "日本", "京都": "日本", "大阪": "日本", "名古屋": "日本",
            "札幌": "日本", "福岡": "日本", "沖繩": "日本",
            "首爾": "韓國", "釜山": "韓國",
            "台北": "台灣", "台東": "台灣", "台南": "台灣", "台中": "台灣",
            "高雄": "台灣", "新北": "台灣", "桃園": "台灣", "新竹": "台灣", "基隆": "台灣",
            "上海": "中國", "北京": "中國", "廣州": "中國", "深圳": "中國",
            "杭州": "中國", "成都": "中國", "重慶": "中國",
            "香港": "中國", "澳門": "中國",
            "新加坡": "新加坡",
            "曼谷": "泰國", "清邁": "泰國",
            "巴黎": "法國",
            "倫敦": "英國",
            "紐約": "美國", "洛杉磯": "美國", "舊金山": "美國", "西雅圖": "美國"
        ]
        
        // 查找匹配的城市
        for (city, country) in countryMap {
            if destination.contains(city) {
                return "\(country) - \(city)"
            }
        }
        
        // 如果找不到匹配，直接返回原字符串
        return destination
    }
    
    /// 评分星星视图（0-5颗星，未评分时显示1颗空心星星）
    @ViewBuilder
    private func ratingStarsView(rating: Double?) -> some View {
        HStack(spacing: 2) {
            if let rating = rating {
                // 有评分：显示5颗星（实心/半颗/空心）
                ForEach(0..<5, id: \.self) { index in
                    let starValue = Double(index) + 1.0
                    if starValue <= rating {
                        // 完整星星
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    } else if starValue - 0.5 <= rating {
                        // 半颗星
                        Image(systemName: "star.lefthalf.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    } else {
                        // 空心星星
                        Image(systemName: "star")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
            } else {
                // 未评分：只显示1颗空心星星
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("my_templates.no_templates".localized())
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 60)
    }
    
    private var bottomInspirationSection: some View {
        EmptyView()
    }
}
