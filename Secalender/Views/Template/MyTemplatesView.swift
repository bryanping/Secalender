import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum TemplateFilterType: String, CaseIterable {
    case myCreations = "我的生成"
    case purchased = "已購買"
    case friendShares = "好友分享"
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
        .sheet(item: $activeSheet) { sheetType in
            Group {
                switch sheetType {
                case .planDetail(let template):
                    NavigationView {
                        PlanDetailView(
                            plan: template.plan,
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
                        onSaveToCalendar: {
                            // 保存到日历后，关闭编辑页面
                            activeSheet = nil
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
        //修改内容：只依赖 userOpenId，一次加载；避免 onAppear/onChange/task 互撞
        .task(id: userManager.userOpenId) {
            let uid = userManager.userOpenId
            guard !uid.isEmpty else { return }
            vm.load(userId: uid)
        }
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
                        Text(filterType.rawValue)
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
                                Label(destination, systemImage: "mappin.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Label("\(template.plan.days.count)天", systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 天数标签
                    Text("\(template.plan.days.count)天")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(template.plan.days.count > 1 ? Color.blue : Color.green)
                        .cornerRadius(12)
                }
                
                Divider()
                
                // 行程预览：显示前2天的活动
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(template.plan.days.enumerated().prefix(2)), id: \.offset) { dayIndex, day in
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
                                        .foregroundColor(.primary)
                                    
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
                    
                    if template.plan.days.count > 2 {
                        Text("...还有 \(template.plan.days.count - 2) 天的行程")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
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

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("还没有保存的行程模板")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 60)
    }
    
    private var bottomInspirationSection: some View {
        EmptyView()
    }
}
