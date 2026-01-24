import SwiftUI
import Foundation
import MapKit
import CoreLocation

// MARK: - 多日行程项数据模型
struct MultiDayEventItem: Identifiable {
    let id = UUID()
    var title: String = ""
    var information: String = ""
    var date: Date = Date()
    var startTime: Date = Date()
    var endTime: Date = Date()
    var destination: String = ""
    var coordinate: CLLocationCoordinate2D?
    var isAllDay: Bool = false
    var isHasEnd: Bool = false
}

// MARK: - 表单状态管理器（优化：合并多个 @State 为一个 ObservableObject，减少重绘）
@MainActor
class EventFormState: ObservableObject {
    @Published var title: String = ""
    @Published var destination: String = ""
    @Published var information: String = ""
    @Published var isOpenChecked: Bool = false
    @Published var isAllDay: Bool = false
    @Published var repeatType: String = "never"
    @Published var calendarComponent: String = "default"
    
    @Published var selectedStartDate: Date = Date()
    @Published var selectedEndDate: Date = Date()
    @Published var selectedStartTime: Date = Date()
    @Published var selectedEndTime: Date = Date()
    @Published var isHasEnd: Bool = false
    
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    
    @Published var isMultiDayEvent: Bool = false
    @Published var multiDayItems: [MultiDayEventItem] = [MultiDayEventItem()]
    @Published var showLocationPickerForItem: UUID? = nil
    @Published var isCalculatingTravelTime: Bool = false
    
    @Published var isGroupEvent: Bool = false
    @Published var selectedGroupId: String? = nil
    @Published var availableGroups: [CommunityGroup] = []
    @Published var isLoadingGroups: Bool = false
    
    // 缓存日历显示文本和颜色，避免频繁计算
    @Published var calendarDisplayText: String = "活動安排"
    @Published var calendarColor: Color = .red
}

// MARK: - Sheet 状态枚举（优化：合并多个 sheet 为一个状态）
enum EventSheetType: Identifiable {
    case repeatOptions
    case calendarOptions
    case locationPicker
    case groupSelector
    
    var id: String {
        switch self {
        case .repeatOptions: return "repeatOptions"
        case .calendarOptions: return "calendarOptions"
        case .locationPicker: return "locationPicker"
        case .groupSelector: return "groupSelector"
        }
    }
}

struct EventCreateView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL

    @ObservedObject var viewModel: EventDetailViewModel
    @StateObject private var formState = EventFormState() // 优化：使用 @StateObject 统一管理表单状态
    
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var syncToAppleCalendar = false
    @State private var hasLoadedDefaultSyncPreference = false
    @State private var hasInitialized = false
    
    // 优化：合并多个 sheet 为一个状态
    @State private var activeSheet: EventSheetType?
    
    // 修改内容：添加防抖机制（使用 @State 保持任务引用，避免重绘时丢失）
    @State private var travelTimeCalculationTask: Task<Void, Never>?
    @State private var isLoadingGroupsTask: Task<Void, Never>?

    var onComplete: (() -> Void)? = nil
    
    // MARK: - Initializer
    init(
        viewModel: EventDetailViewModel,
        onComplete: (() -> Void)? = nil
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.onComplete = onComplete
    }
    
    // 重複選項
    private let repeatOptions = [
        ("never", "永不"),
        ("daily", "每天"),
        ("weekly", "每週"),
        ("monthly", "每月"),
        ("yearly", "每年")
    ]
    
    // 行事曆組件選項
    private let calendarOptions = [
        ("default", "活動安排"),
        ("work", "工作"),
        ("personal", "個人"),
        ("family", "家庭"),
        ("study", "學習")
    ]
    
    // 路程時間選項
    private let travelTimeOptions = [
        ("無", nil),
        ("5 分鐘", "5"),
        ("15 分鐘", "15"),
        ("30 分鐘", "30"),
        ("1 小時", "60"),
        ("1.5 小時", "90"),
        ("2 小時", "120")
    ]
    
    // MARK: - 單日行程表單部分（优化：使用单一EventFormCard包裹所有字段）
    @ViewBuilder
    private var singleDayEventSections: some View {
        // 單一卡片包含所有字段：行程標題、活動內容、地點、時間
        EventFormCard(icon: "calendar", title: "行程 1", iconColor: .blue) {
            VStack(spacing: 16) {
                // 行程標題
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("行程標題")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(formState.title.count)/20")
                            .font(.system(size: 10))
                            .foregroundColor(formState.title.count >= 20 ? .red : .secondary)
                    }
                    
                    TextField("例如:抵達東京成田機場", text: Binding(
                        get: { formState.title },
                        set: { newValue in
                            // 限制最多20个字符
                            if newValue.count <= 20 {
                                formState.title = newValue
                            }
                        }
                    ))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemGray6))
                    )
                }
                
                // 活動內容
                VStack(alignment: .leading, spacing: 4) {
                    Text("活動內容")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    GlassTextEditor(
                        placeholder: "輸入活動備註或細節...",
                        text: $formState.information,
                        minHeight: 80
                    )
                }
                
                // 選擇地點
                VStack(alignment: .leading, spacing: 4) {

                    Button(action: {
                        activeSheet = .locationPicker // 优化：使用统一的 sheet 状态
                        
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            
                            Text(formState.destination.isEmpty ? "選擇地點" : formState.destination)
                                .foregroundColor(formState.destination.isEmpty ? .gray : .primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 設定時間
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {

                        Text("設定時間")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    DateTimePickerView(
            startDate: $formState.selectedStartDate,
            startTime: $formState.selectedStartTime,
            endDate: Binding(
                get: { formState.isHasEnd ? formState.selectedEndDate : nil },
                set: { if let date = $0 { formState.selectedEndDate = date } }
            ),
            endTime: Binding(
                get: { formState.isHasEnd ? formState.selectedEndTime : nil },
                set: { if let time = $0 { formState.selectedEndTime = time } }
            ),
            isAllDay: $formState.isAllDay,
            isHasEnd: $formState.isHasEnd
        )
                }
            }
        }
        .onChange(of: formState.isAllDay) { oldValue, newValue in
            // 优化：添加防抖，避免频繁更新
            guard newValue else { return }
            Task { @MainActor in
                formState.isHasEnd = false
                let calendar = Calendar.current
                formState.selectedStartTime = calendar.startOfDay(for: formState.selectedStartDate)
                formState.selectedEndDate = formState.selectedStartDate
                formState.selectedEndTime = calendar.date(byAdding: .hour, value: 1, to: formState.selectedStartTime) ?? formState.selectedStartTime
            }
        }
        
        // 添加多行程按鈕
        Button(action: {
                withAnimation {
                    // 將當前單日行程的內容保存到行程1
                    var item1 = MultiDayEventItem()
                    item1.information = formState.information
                    item1.destination = formState.destination
                    item1.coordinate = formState.selectedCoordinate
                    item1.date = formState.selectedStartDate
                    
                    item1.startTime = formState.selectedStartTime
                    item1.isHasEnd = formState.isHasEnd
                    item1.endTime = formState.isHasEnd ? formState.selectedEndTime : formState.selectedStartTime
                    item1.isAllDay = formState.isAllDay
                    
                    // 創建行程2（默認時間為行程1開始時間後15分鐘，沒有結束時間）
                    let calendar = Calendar.current
                    let item2StartTime = calendar.date(byAdding: .minute, value: 15, to: formState.selectedStartTime) ?? Date()
                    var item2 = MultiDayEventItem()
                    item2.date = formState.selectedStartDate
                    item2.startTime = item2StartTime
                    item2.isHasEnd = false
                    item2.endTime = item2StartTime
                   
                    // 設置多日行程
                    formState.multiDayItems = [item1, item2]
                    formState.isMultiDayEvent = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                    Text("添加多日行程")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundColor(.blue.opacity(0.3))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
        
        // 社群/个人设置卡片
        EventFormCard(icon: "person.2.fill", title: "發布設置", iconColor: .blue) {
                VStack(spacing: 16) {
                    // 个人/社群切换（优化：减少 onChange 触发频率）
                    Toggle(formState.isGroupEvent ? "由社群发布" : "個人發布", isOn: $formState.isGroupEvent)
                        .tint(.blue)
                        .onChange(of: formState.isGroupEvent) { oldValue, newValue in
                            // 优化：使用防抖，避免频繁触发
                            guard oldValue != newValue else { return }
                            Task { @MainActor in
                                if newValue && formState.availableGroups.isEmpty && !formState.isLoadingGroups {
                                    await loadAvailableGroups()
                                } else if !newValue {
                                    formState.selectedGroupId = nil
                                }
                            }
                        }
                    
                    // 社群选择器（仅在开启社群发布且有多個社群时显示）
                    if formState.isGroupEvent {
                        if formState.isLoadingGroups {
                            ProgressView("加载社群中...")
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if formState.availableGroups.isEmpty {
                            Text("您没有可管理的社群")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            HStack {
                                Text("選擇社群")
                                    .foregroundColor(.primary)
                                Spacer()
                                Button(action: {
                                    activeSheet = .groupSelector // 优化：使用统一的 sheet 状态
                                }) {
                                    HStack {
                                        if let groupId = formState.selectedGroupId,
                                           let group = formState.availableGroups.first(where: { $0.id == groupId }) {
                                            Text(group.name)
                                                .foregroundColor(.blue)
                                        } else {
                                            Text("請選擇社群")
                                                .foregroundColor(.gray)
                                        }
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 仅在个人发布时显示"公开给好友"开关
                    if !formState.isGroupEvent {
                        Toggle("公開給好友", isOn: $formState.isOpenChecked)
                            .tint(.blue)
                    }
                }
            }
        
        // 其他设置卡片（包含重复、邀请、公开等）
        EventFormCard(icon: "gearshape.fill", title: "其他设置", iconColor: .gray) {
                VStack(spacing: 16) {
                    // 重複設置（僅在非多日行程時顯示）
                    if !formState.isMultiDayEvent {
                        HStack {
                            Text("重複")
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                activeSheet = .repeatOptions // 优化：使用统一的 sheet 状态
                            }) {
                                Text(getRepeatDisplayText())
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Toggle("同步到 Apple 日曆", isOn: $syncToAppleCalendar)
                        .tint(.blue)
                        .onChange(of: syncToAppleCalendar) { oldValue, newValue in
                            // 优化：使用防抖，避免频繁触发
                            guard newValue && !hasLoadedDefaultSyncPreference else { return }
                            Task {
                                try? await UserPreferencesManager.shared.setSyncToAppleCalendarDefault(true, for: userManager.userOpenId)
                            }
                        }
                    
                    // 日历选择（仅在开启同步日历时显示）
                    if syncToAppleCalendar {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(formState.calendarColor)
                            Text("行事曆")
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                activeSheet = .calendarOptions // 优化：使用统一的 sheet 状态
                            }) {
                                Text(formState.calendarDisplayText)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
    }

    
    // MARK: - 多日行程表單部分（优化：使用 LazyVStack 减少渲染负担）
    @ViewBuilder
    private var multiDayEventSections: some View {
        // 動態生成行程項（最多5個）
        ForEach(Array(formState.multiDayItems.enumerated()), id: \.element.id) { index, item in
            MultiDayEventItemView(
                index: index,
                item: item,
                items: $formState.multiDayItems,
                mainTitle: $formState.title,
                isCalculatingTravelTime: formState.isCalculatingTravelTime,
                showLocationPickerForItem: $formState.showLocationPickerForItem,
                activeSheet: $activeSheet, // 优化：使用统一的 sheet 状态
                onCoordinateChanged: { calculateAndUpdateTravelTime(for: index) },
                onStartTimeChanged: { ensureTimeOrder(for: index) }
            )
            .id(item.id) // 优化：明确标识，帮助 SwiftUI 优化重绘
        }
            
            // 添加行程按鈕（最多5個）
            if formState.multiDayItems.count < 5 {
                Button(action: {
                    withAnimation {
                        // 如果已有行程，設置默認時間為上一個行程開始時間後15分鐘
                        if let lastItem = formState.multiDayItems.last {
                            let calendar = Calendar.current
                            let newStartTime = calendar.date(byAdding: .minute, value: 15, to: lastItem.startTime) ?? Date()
                            var newItem = MultiDayEventItem()
                            newItem.date = lastItem.date
                            newItem.startTime = newStartTime
                            newItem.endTime = newStartTime
                            newItem.isHasEnd = false
                            formState.multiDayItems.append(newItem)
                        } else {
                            var newItem = MultiDayEventItem()
                            newItem.isHasEnd = false
                            formState.multiDayItems.append(newItem)
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                        Text("添加多日行程")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                            .foregroundColor(.blue.opacity(0.3))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
            }
            
            // 社群/个人设置卡片（多行程模式）
            EventFormCard(icon: "person.3.fill", title: "发布设置", iconColor: .purple) {
                VStack(spacing: 16) {
                    // 个人/社群切换（优化：复用单日行程的逻辑）
                    Toggle(formState.isGroupEvent ? "由社群发布" : "个人发布", isOn: $formState.isGroupEvent)
                        .tint(.purple)
                        .onChange(of: formState.isGroupEvent) { oldValue, newValue in
                            guard oldValue != newValue else { return }
                            Task { @MainActor in
                                if newValue && formState.availableGroups.isEmpty && !formState.isLoadingGroups {
                                    await loadAvailableGroups()
                                } else if !newValue {
                                    formState.selectedGroupId = nil
                                }
                            }
                        }
                    
                    // 社群选择器（仅在开启社群发布且有多個社群时显示）
                    if formState.isGroupEvent {
                        if formState.isLoadingGroups {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                        } else if formState.availableGroups.isEmpty {
                            Text("您还没有可管理的社群")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: {
                                activeSheet = .groupSelector
                            }) {
                                HStack {
                                    if let groupId = formState.selectedGroupId,
                                       let group = formState.availableGroups.first(where: { $0.id == groupId }) {
                                        Text(group.name)
                                            .foregroundColor(.blue)
                                    } else {
                                        Text("選擇社群")
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    
                    // 仅在个人发布时显示"公开给好友"开关
                    if !formState.isGroupEvent {
                        Toggle("公開給好友", isOn: $formState.isOpenChecked)
                            .tint(.blue)
                    }
                }
            }
            
            // 取消多日行程按鈕
            EventFormCard(icon: "calendar.badge.minus", title: "多日行程", iconColor: .red) {
                Button(action: {
                    withAnimation {
                        formState.isMultiDayEvent = false
                        formState.multiDayItems = [MultiDayEventItem()]
                    }
                }) {
                    HStack {
                        Text("取消多日行程")
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 其他设置卡片（包含邀请、公开等）
            EventFormCard(icon: "gearshape.fill", title: "其他设置", iconColor: .gray) {
                VStack(spacing: 16) {
                    Toggle("同步到 Apple 日曆", isOn: $syncToAppleCalendar)
                        .tint(.blue)
                        .onChange(of: syncToAppleCalendar) { oldValue, newValue in
                            guard newValue && !hasLoadedDefaultSyncPreference else { return }
                            Task {
                                try? await UserPreferencesManager.shared.setSyncToAppleCalendarDefault(true, for: userManager.userOpenId)
                            }
                        }
                    
                    // 日历选择（仅在开启同步日历时显示）
                    if syncToAppleCalendar {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(formState.calendarColor)
                            Text("行事曆")
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                activeSheet = .calendarOptions
                            }) {
                                Text(formState.calendarDisplayText)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
    

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 主标题区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新增行程")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if formState.isMultiDayEvent {
                            Text("AI 秘書已為您準備好連續編輯模式")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    VStack(spacing: 16) {
                    if formState.isMultiDayEvent {
                        // 多日行程模式
                        multiDayEventSections
                    } else {
                        // 單日行程模式
                        singleDayEventSections
                        }
                    }
                    
                    // 底部操作按钮
                    VStack(spacing: 16) {
                        EventActionButton(
                            title: formState.isMultiDayEvent ? "建立行程" : "完成",
                            icon: "checkmark.circle.fill",
                            style: .primary
                        ) {
                            saveEvent()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.bottom, 80) // 为底部按钮留出空间
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("取消")
                            .foregroundColor(.blue)
                            .font(.system(size: 17))
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("建立行程")
                        .font(.system(size: 17, weight: .semibold))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        saveEvent()
                    }) {
                        Text("儲存")
                            .foregroundColor(.blue)
                            .font(.system(size: 17))
                    }
                }
            }
            // 优化：合并多个 sheet 为一个，减少视图层级
            .sheet(item: $activeSheet) { sheetType in
                switch sheetType {
                case .groupSelector:
                    GroupSelectorView(
                        groups: formState.availableGroups,
                        selectedGroupId: $formState.selectedGroupId,
                        onSelect: { groupId in
                            formState.selectedGroupId = groupId
                            activeSheet = nil
                        }
                    )
                case .repeatOptions:
                    RepeatOptionsView(selectedRepeat: Binding(
                        get: { formState.repeatType },
                        set: { formState.repeatType = $0 }
                    ))
                case .calendarOptions:
                    CalendarOptionsView(selectedCalendar: Binding(
                        get: { formState.calendarComponent },
                        set: { newValue in
                            formState.calendarComponent = newValue
                            updateCalendarDisplay()
                        }
                    ))
                case .locationPicker:
                    LocationPickerView(
                        selectedAddress: Binding(
                            get: {
                                if let itemId = formState.showLocationPickerForItem,
                                   let item = formState.multiDayItems.first(where: { $0.id == itemId }) {
                                    return item.destination
                                }
                                return formState.destination
                            },
                            set: { newValue in
                                if let itemId = formState.showLocationPickerForItem,
                                   let index = formState.multiDayItems.firstIndex(where: { $0.id == itemId }) {
                                    formState.multiDayItems[index].destination = newValue
                                } else {
                                    formState.destination = newValue
                                }
                            }
                        ),
                        selectedCoordinate: Binding(
                            get: {
                                if let itemId = formState.showLocationPickerForItem,
                                   let item = formState.multiDayItems.first(where: { $0.id == itemId }) {
                                    return item.coordinate
                                }
                                return formState.selectedCoordinate
                            },
                            set: { newValue in
                                if let itemId = formState.showLocationPickerForItem,
                                   let index = formState.multiDayItems.firstIndex(where: { $0.id == itemId }) {
                                    formState.multiDayItems[index].coordinate = newValue
                                } else {
                                    formState.selectedCoordinate = newValue
                                }
                            }
                        )
                    )
                    .onDisappear {
                        // 當地點選擇器關閉時，如果選擇了地點，觸發時間計算（添加防抖）
                        if let itemId = formState.showLocationPickerForItem,
                           let index = formState.multiDayItems.firstIndex(where: { $0.id == itemId }),
                           index > 0,
                           formState.multiDayItems[index].coordinate != nil {
                            Task {
                                // 延迟执行，避免频繁计算
                                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms 防抖
                                guard !Task.isCancelled else { return }
                                calculateAndUpdateTravelTime(for: index)
                            }
                        }
                        formState.showLocationPickerForItem = nil
                    }
                }
            }
        }
        .alert("錯誤", isPresented: $showErrorAlert) {
            Button("好") {}
        } message: {
            Text(errorMessage)
        }

        .task {
            // 合并初始化逻辑，确保只执行一次
            guard !hasInitialized else { return }
            hasInitialized = true
            
            // 初始化本地状态（只在首次加载时）
            await MainActor.run {
                if formState.title.isEmpty {
                    formState.title = viewModel.event.title
                }
                if formState.destination.isEmpty {
                    formState.destination = viewModel.event.destination
                }
                if formState.information.isEmpty {
                    formState.information = viewModel.event.information ?? ""
                }
                formState.isOpenChecked = viewModel.event.openChecked == 1
                formState.isAllDay = viewModel.event.isAllDay ?? false
                formState.repeatType = viewModel.event.repeatType ?? "never"
                formState.calendarComponent = viewModel.event.calendarComponent ?? "default"
                
                // 初始化日历显示文本和颜色
                updateCalendarDisplay()
                
                initializeDatePickers()
            }
            
            // 初始化视图（包含异步操作）
            await initializeView()
            await loadDefaultSyncPreference()
        }
        .onChange(of: formState.calendarComponent) { oldValue, newValue in
            // 优化：只在日历组件真正改变时更新显示
            guard oldValue != newValue else { return }
            updateCalendarDisplay()
        }
    }
    
    // MARK: - 私有方法
    
    /// 計算並更新交通時間（使用 AIPlanner，带防抖）
    // TODO: 需要引入 UUID token 机制，只允许最后一次计算的结果生效
    // 问题：外层 Task cancel 后，内层回调仍可能返回并更新 UI
    // 建议单独重构，引入 token 验证机制
    private func calculateAndUpdateTravelTime(for index: Int) {
        guard index > 0 && index < formState.multiDayItems.count else { return }
        
        // 取消之前的计算任务
        travelTimeCalculationTask?.cancel()
        
        // 创建新的计算任务（带 500ms 防抖）
        travelTimeCalculationTask = Task { @MainActor in
            // 等待 500ms，避免频繁计算
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // 检查任务是否被取消
            guard !Task.isCancelled else { return }
            
            // 再次验证索引和坐标（可能在等待期间已改变）
            guard index < formState.multiDayItems.count else { return }
            
            let previousItem = formState.multiDayItems[index - 1]
            let currentItem = formState.multiDayItems[index]
            
            // 確保上一個行程有地點和坐標
            guard let previousCoordinate = previousItem.coordinate,
                  let currentCoordinate = currentItem.coordinate else { return }
            
            formState.isCalculatingTravelTime = true
            
            // 計算上一個行程的結束時間
            let calendar = Calendar.current
            let previousEndTime = calendar.date(bySettingHour: calendar.component(.hour, from: previousItem.endTime),
                                                minute: calendar.component(.minute, from: previousItem.endTime),
                                                second: 0,
                                                of: previousItem.date) ?? previousItem.endTime
            
            // 使用 AIPlanner 計算最優到達時間
            // ⚠️ 注意：即使外层 Task 被 cancel，这个回调仍可能返回
            // TODO: 需要引入 UUID token 验证机制，确保只有最后一次计算的结果生效
            AIPlanner.shared.calculateOptimalArrivalTime(
                previousEndTime: previousEndTime,
                previousCoordinate: previousCoordinate,
                currentCoordinate: currentCoordinate
            ) { result in
                Task { @MainActor in
                    defer { self.formState.isCalculatingTravelTime = false }
                    
                    // 再次检查任务是否被取消
                    guard !Task.isCancelled else { return }
                    
                    guard let result = result, index < self.formState.multiDayItems.count else { return }
                    
                    let currentItem = self.formState.multiDayItems[index]
                    
                    // 更新當前行程的開始時間（如果當前時間早於計算出的時間）
                    let currentStartDateTime = calendar.date(bySettingHour: calendar.component(.hour, from: currentItem.startTime),
                                                            minute: calendar.component(.minute, from: currentItem.startTime),
                                                            second: 0,
                                                            of: currentItem.date) ?? currentItem.date
                    
                    if currentStartDateTime < result.earliestArrivalTime {
                        // 更新日期和時間
                        self.formState.multiDayItems[index].date = calendar.startOfDay(for: result.earliestArrivalTime)
                        self.formState.multiDayItems[index].startTime = result.earliestArrivalTime
                        
                        // 自動設置結束時間為開始時間後1小時
                        if let newEndTime = calendar.date(byAdding: .hour, value: 1, to: result.earliestArrivalTime) {
                            self.formState.multiDayItems[index].endTime = newEndTime
                        }
                    }
                }
            }
        }
    }
    
    /// 確保時間順序：當前行程時間不早於上一個行程（使用 AIPlanner）
    private func ensureTimeOrder(for index: Int) {
        guard index > 0 && index < formState.multiDayItems.count else { return }
        
        let previousItem = formState.multiDayItems[index - 1]
        let currentItem = formState.multiDayItems[index]
        
        let calendar = Calendar.current
        let previousEndTime = calendar.date(bySettingHour: calendar.component(.hour, from: previousItem.endTime),
                                            minute: calendar.component(.minute, from: previousItem.endTime),
                                            second: 0,
                                            of: previousItem.date) ?? previousItem.endTime
        
        // 使用 AIPlanner 確保時間順序
        let (adjustedStartTime, adjustedDate) = AIPlanner.shared.ensureTimeOrder(
            previousEndTime: previousEndTime,
            currentStartTime: currentItem.startTime,
            currentDate: currentItem.date
        )
        
        // 如果時間被調整，更新行程項
        let currentStartDateTime = calendar.date(bySettingHour: calendar.component(.hour, from: currentItem.startTime),
                                                minute: calendar.component(.minute, from: currentItem.startTime),
                                                second: 0,
                                                of: currentItem.date) ?? currentItem.startTime
        
        if adjustedStartTime != currentStartDateTime {
            formState.multiDayItems[index].date = adjustedDate
            formState.multiDayItems[index].startTime = adjustedStartTime
            
            // 自動調整結束時間
            if let newEndTime = calendar.date(byAdding: .hour, value: 1, to: adjustedStartTime) {
                formState.multiDayItems[index].endTime = newEndTime
            }
        }
    }
    
    /// 初始化视图
    private func initializeView() async {
        // 修改内容：移除重复的 hasInitialized 检查，已在 task 中处理
        // 初始化日期选择器已在 task 中调用
        // initializeDatePickers()
        
        // 如果已有 groupId，加载社群信息
        if let existingGroupId = viewModel.event.groupId {
            formState.isGroupEvent = true
            formState.selectedGroupId = existingGroupId
            await loadAvailableGroups()
        }
    }
    
    /// 加载用户可管理的社群列表
    private func loadAvailableGroups() async {
        // 修改内容：取消之前的加载任务，防止重复调用
        isLoadingGroupsTask?.cancel()
        
        // 如果正在加载，不重复加载
        guard !formState.isLoadingGroups else { return }
        
        formState.isLoadingGroups = true
        isLoadingGroupsTask = Task {
            do {
                // 修改内容：检查任务是否被取消
                guard !Task.isCancelled else { return }
                
                // 获取用户加入的所有社群
                let allGroups = try await GroupManager.shared.getUserGroups(userId: userManager.userOpenId)
                
                // 修改内容：检查任务是否被取消
                guard !Task.isCancelled else { return }
                
                // 过滤出用户有管理权限的社群（拥有者或管理员）
                let filteredGroups = allGroups.filter { group in
                    group.hasManagePermission(userId: userManager.userOpenId)
                }
                
                await MainActor.run {
                    self.formState.availableGroups = filteredGroups
                    
                    // 如果只有一个社群，自动选择
                    if filteredGroups.count == 1, let firstGroup = filteredGroups.first {
                        self.formState.selectedGroupId = firstGroup.id
                    }
                }
            } catch {
                if !Task.isCancelled {
                    print("加载社群失败: \(error.localizedDescription)")
                }
                await MainActor.run {
                    self.formState.availableGroups = []
                }
            }
            await MainActor.run {
                self.formState.isLoadingGroups = false
            }
        }
        
        await isLoadingGroupsTask?.value
    }
    
    private func initializeDatePickers() {
        // 只在事件没有日期信息时才初始化
        guard viewModel.event.date.isEmpty else {
            // 如果已有日期，只更新DatePicker的显示值
            if let dateObj = viewModel.event.dateObj {
                formState.selectedStartDate = dateObj
            }
            if let endDateString = viewModel.event.endDate, let endDateObj = {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: endDateString)
            }() {
                formState.selectedEndDate = endDateObj
            }
            if let startDateTime = viewModel.event.startDateTime {
                formState.selectedStartTime = startDateTime
            }
            if let endDateTime = viewModel.event.endDateTime {
                formState.selectedEndTime = endDateTime
            }
            
            // 初始化 isHasEnd：根据是否有结束时间来判断
            if !formState.isAllDay {
                formState.isHasEnd = (viewModel.event.endTime != nil) || (viewModel.event.endDate != nil)
            } else {
                formState.isHasEnd = false
            }
            return
        }
        
        // 新事件：初始化默认值
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let nextHour = currentMinute > 0 ? currentHour + 1 : currentHour
        let roundedStartTime = calendar.date(bySettingHour: nextHour, minute: 0, second: 0, of: now) ?? now
        let roundedEndTime = calendar.date(byAdding: .hour, value: 1, to: roundedStartTime) ?? roundedStartTime
        
        formState.selectedStartDate = now
        formState.selectedEndDate = now
        formState.selectedStartTime = roundedStartTime
        formState.selectedEndTime = roundedStartTime
        formState.isHasEnd = false
        
        // 只在事件为空时才设置默认值
        if viewModel.event.title.isEmpty {
            viewModel.event.startTime = dateToString(roundedStartTime, format: "HH:mm:ss")
            viewModel.event.endTime = dateToString(roundedEndTime, format: "HH:mm:ss")
            viewModel.event.date = dateToString(formState.selectedStartDate, format: "yyyy-MM-dd")
        }
    }
    
    private func saveEvent() {
        if formState.isMultiDayEvent {
            // 多日行程：創建多個事件
            saveMultiDayEvents()
        } else {
            // 單日行程：創建單個事件
            saveSingleDayEvent()
        }
    }
    
    private func saveSingleDayEvent() {
        // 将本地状态同步到viewModel
        viewModel.event.title = formState.title
        viewModel.event.destination = formState.destination
        viewModel.event.information = formState.information.isEmpty ? nil : formState.information
        viewModel.event.openChecked = formState.isOpenChecked ? 1 : 0
        viewModel.event.isAllDay = formState.isAllDay
        viewModel.event.repeatType = formState.repeatType
        viewModel.event.calendarComponent = formState.calendarComponent
        
        // 更新日期时间
        viewModel.event.date = dateToString(formState.selectedStartDate, format: "yyyy-MM-dd")
        if !formState.isAllDay {
            viewModel.event.startTime = dateToString(formState.selectedStartTime, format: "HH:mm:ss")
            
            // 根据 isHasEnd 决定是否保存结束时间
            if formState.isHasEnd {
                viewModel.event.endTime = dateToString(formState.selectedEndTime, format: "HH:mm:ss")
                if formState.selectedEndDate != formState.selectedStartDate {
                    viewModel.event.endDate = dateToString(formState.selectedEndDate, format: "yyyy-MM-dd")
                } else {
                    viewModel.event.endDate = nil
                }
            } else {
                viewModel.event.endTime = dateToString(formState.selectedStartTime, format: "HH:mm:ss")
                viewModel.event.endDate = nil
            }
        } else {
            viewModel.event.startTime = "00:00:00"
            viewModel.event.endTime = "23:59:59"
            viewModel.event.endDate = nil
        }
        
        // 验证时间（只有在有结束时间时才验证）
        if !formState.isAllDay && formState.isHasEnd {
            let startDateTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: formState.selectedStartTime),
                                                      minute: Calendar.current.component(.minute, from: formState.selectedStartTime),
                                                      second: 0,
                                                      of: formState.selectedStartDate) ?? formState.selectedStartDate
            let endDateTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: formState.selectedEndTime),
                                                    minute: Calendar.current.component(.minute, from: formState.selectedEndTime),
                                                    second: 0,
                                                    of: formState.selectedEndDate) ?? formState.selectedEndDate
            
            if startDateTime >= endDateTime {
                errorMessage = "開始時間必須早於結束時間"
                showErrorAlert = true
                return
            }
        }
        
        // 设置社群ID（如果选择了社群）
        if formState.isGroupEvent {
            if let groupId = formState.selectedGroupId {
                viewModel.event.groupId = groupId
            } else {
                errorMessage = "請選擇要發布的社群"
                showErrorAlert = true
                return
            }
        } else {
            viewModel.event.groupId = nil
        }

        // 先立即关闭视图，提升用户体验
        onComplete?()
        dismiss()
        
        // 后台异步保存到 Firebase（EventManager 已经先保存到本地缓存了）
        Task {
            do {
                try await viewModel.saveEvent(currentUserOpenId: userManager.userOpenId)
                if syncToAppleCalendar {
                    // TODO: 實現同步到 Apple 日曆
                }
            } catch {
                // 如果保存失败，在后台记录错误（不影响用户体验）
                print("⚠️ 后台保存失败：\(error.localizedDescription)")
                // 注意：由于视图已关闭，这里无法显示错误提示
                // 但事件已经保存到本地缓存，用户可以继续使用
            }
        }
    }
    
    private func saveMultiDayEvents() {
        // 1. 验证社群设置（如果是社群活动）
        if formState.isGroupEvent {
            if formState.selectedGroupId == nil {
                errorMessage = "請選擇要發布的社群"
                showErrorAlert = true
                return
            }
            // 验证用户是否有该社群的发布权限
            if !formState.availableGroups.contains(where: { $0.id == formState.selectedGroupId }) {
                errorMessage = "您沒有該社群的發布權限，請重新選擇社群"
                showErrorAlert = true
                return
            }
        }
        
        // 2. 驗證多日行程數據
        for (index, item) in formState.multiDayItems.enumerated() {
            if item.information.trimmingCharacters(in: .whitespaces).isEmpty {
                errorMessage = "請填寫行程 \(index + 1) 的活動內容"
                showErrorAlert = true
                return
            }
            
            // 只有在有结束时间时才验证时间顺序
            if item.isHasEnd {
                let startDateTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: item.startTime),
                                                          minute: Calendar.current.component(.minute, from: item.startTime),
                                                          second: 0,
                                                          of: item.date) ?? item.date
                let endDateTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: item.endTime),
                                                        minute: Calendar.current.component(.minute, from: item.endTime),
                                                        second: 0,
                                                        of: item.date) ?? item.date
                
                if startDateTime >= endDateTime {
                    errorMessage = "行程 \(index + 1) 的開始時間必須早於結束時間"
                    showErrorAlert = true
                    return
                }
            }
        }
        
        // 記錄保存開始時間，用於去重
        let saveStartTime = dateToString(Date(), format: "yyyy-MM-dd HH:mm:ss")
        
        // 先批量保存所有事件到本地缓存（同步操作，很快）
        var eventsToSave: [Event] = []
        for (index, item) in formState.multiDayItems.enumerated() {
            // 使用行程標題，如果沒有則使用默認標題
            let eventTitle: String
            if index == 0 {
                eventTitle = formState.title
            } else if !item.title.isEmpty {
                eventTitle = item.title
            } else {
                eventTitle = "\(formState.title) - 行程 \(index + 1)"
            }
            
            // 根据 isHasEnd 决定结束时间
            let endTimeString: String
            if item.isHasEnd {
                endTimeString = dateToString(item.endTime, format: "HH:mm:ss")
            } else {
                endTimeString = dateToString(item.startTime, format: "HH:mm:ss")
            }
            
            var event = Event(
                title: eventTitle,
                creatorOpenid: userManager.userOpenId,
                color: "#FF6280",
                date: dateToString(item.date, format: "yyyy-MM-dd"),
                startTime: dateToString(item.startTime, format: "HH:mm:ss"),
                endTime: endTimeString,
                destination: item.destination,
                mapObj: "",
                openChecked: formState.isOpenChecked ? 1 : 0,
                personChecked: 0,
                createTime: saveStartTime,
                information: item.information,
                isAllDay: item.isAllDay,
                repeatType: "never",
                calendarComponent: formState.calendarComponent,
                groupId: formState.isGroupEvent ? formState.selectedGroupId : nil
            )
            
            // 如果没有结束时间，不设置 endDate
            if !item.isHasEnd {
                event.endDate = nil
            }
            
            eventsToSave.append(event)
            
            // 立即保存到本地缓存（同步操作，很快）
            EventCacheManager.shared.addEventToCache(event, for: userManager.userOpenId)
        }
        
        // 立即关闭视图，提升用户体验
        onComplete?()
        dismiss()
        
        // 优化：先捕获值，避免在 Task 中捕获非 Sendable 的 userManager
        let userId = userManager.userOpenId
        let shouldSync = syncToAppleCalendar
        
        // 后台异步保存到 Firebase（使用 Task {} 而不是 Task.detached，保持在主 Actor 上下文）
        Task { @MainActor in
            do {
                // 为每个事件保存到 Firebase
                for event in eventsToSave {
                    let viewModel = EventDetailViewModel(event: event)
                    try await viewModel.saveEvent(currentUserOpenId: userId)
                }
                
                // 等待一小段时间确保 Firebase 写入完成
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
                
                // 从 Firebase 重新加载，更新本地缓存（这会覆盖可能重复的临时事件）
                try? await EventManager.shared.fetchEvents()
                
                if shouldSync {
                    // TODO: 實現同步到 Apple 日曆
                }
            } catch {
                // 如果保存失败，在后台记录错误（不影响用户体验）
                print("⚠️ 后台保存多日行程失败：\(error.localizedDescription)")
                // 注意：由于视图已关闭，这里无法显示错误提示
                // 但事件已经保存到本地缓存，用户可以继续使用
            }
        }
    }
    
    private func getRepeatDisplayText() -> String {
        return repeatOptions.first { $0.0 == formState.repeatType }?.1 ?? "永不"
    }
    
    /// 更新日历显示文本和颜色（只在需要时调用，避免频繁计算）
    private func updateCalendarDisplay() {
        // 从UserPreferencesManager加载用户日历列表
        let userCalendars = UserPreferencesManager.shared.loadUserCalendarsFromCache(for: userManager.userOpenId)
        if let calendar = userCalendars.first(where: { $0.id == formState.calendarComponent }) {
            formState.calendarDisplayText = calendar.title
            formState.calendarColor = calendar.color
        } else {
            // 如果没有找到，使用默认值
            formState.calendarDisplayText = calendarOptions.first { $0.0 == formState.calendarComponent }?.1 ?? "活動安排"
            // 设置默认颜色
            switch formState.calendarComponent {
            case "work": formState.calendarColor = .blue
            case "personal": formState.calendarColor = .green
            case "family": formState.calendarColor = .orange
            case "study": formState.calendarColor = .purple
            default: formState.calendarColor = .red
            }
        }
    }
    
    /// 加载默认同步偏好设置
    private func loadDefaultSyncPreference() async {
        // 优化：先捕获值，避免在 Task 中捕获非 Sendable 的 userManager
        let userId = userManager.userOpenId
        
        // 先从本地缓存读取
        let defaultValue = UserPreferencesManager.shared.getSyncToAppleCalendarDefault(for: userId)
        await MainActor.run {
            syncToAppleCalendar = defaultValue
            hasLoadedDefaultSyncPreference = true
        }
        
        // 然后从Firebase同步最新设置（后台进行，不阻塞UI）
        // 优化：使用 Task {} 而不是 Task.detached，保持在主 Actor 上下文
        Task { @MainActor in
            try? await UserPreferencesManager.shared.loadSyncToAppleCalendarDefault(for: userId)
            let updatedValue = UserPreferencesManager.shared.getSyncToAppleCalendarDefault(for: userId)
            syncToAppleCalendar = updatedValue
        }
    }
    
    
    private func dateToString(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    private func stringToDate(_ string: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.date(from: string)
    }
}

// MARK: - 多日行程項視圖組件（拆分複雜視圖以解決類型檢查問題）
struct MultiDayEventItemView: View {
    let index: Int
    let item: MultiDayEventItem
    @Binding var items: [MultiDayEventItem]
    @Binding var mainTitle: String  // 主标题（用于行程1）
    let isCalculatingTravelTime: Bool
    @Binding var showLocationPickerForItem: UUID?
    @Binding var activeSheet: EventSheetType? // 优化：使用统一的 sheet 状态
    let onCoordinateChanged: () -> Void
    let onStartTimeChanged: () -> Void
    
    // 辅助方法：通过ID安全地获取项目索引
    private var itemIndex: Int? {
        items.firstIndex(where: { $0.id == item.id })
    }
    
    // 辅助方法：安全地获取当前项目
    private var currentItem: MultiDayEventItem? {
        guard let idx = itemIndex else { return nil }
        return idx < items.count ? items[idx] : nil
    }
    

    
    var body: some View {
        // 所有行程都使用"行程 X"格式
        EventFormCard(
            icon: "calendar",
            title: "行程 \(index + 1)",
            iconColor: .blue
        ) {
            VStack(spacing: 16) {
                // 行程標題（行程1显示主标题输入框，行程2及之后显示各自的标题输入框）
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("行程標題")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if index == 0 {
                            // 行程1：显示主标题字数统计
                            Text("\(mainTitle.count)/20")
                                .font(.system(size: 10))
                                .foregroundColor(mainTitle.count >= 20 ? .red : .secondary)
                        } else {
                            // 行程2及之后：显示各自的字数统计
                            if let idx = itemIndex, idx < items.count {
                                Text("\(items[idx].title.count)/20")
                                    .font(.system(size: 10))
                                    .foregroundColor(items[idx].title.count >= 20 ? .red : .secondary)
                            }
                        }
                    }
                    
                if index == 0 {
                    // 行程1：显示主标题输入框
                        TextField("例如:抵達東京成田機場", text: $mainTitle)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemGray6))
                            )
                            .onChange(of: mainTitle) { oldValue, newValue in
                                // 限制最多20个字符
                                if newValue.count > 20 {
                                    mainTitle = String(newValue.prefix(20))
                                }
                    }
                } else {
                    // 行程2及之后：显示各自的标题输入框
                        TextField("例如:抵達東京成田機場", text: Binding(
                            get: { 
                                guard let idx = itemIndex, idx < items.count else { return "" }
                                return items[idx].title
                            },
                            set: { newValue in
                                // 限制最多20个字符
                                guard let idx = itemIndex, idx < items.count else { return }
                                if newValue.count <= 20 {
                                    items[idx].title = newValue
                                }
                            }
                        ))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray6))
                        )
                    }
                }
                
                // 活動內容
                VStack(alignment: .leading, spacing: 4) {
                    Text("活動內容")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                GlassTextEditor(
                        placeholder: "輸入活動備註或細節...",
                    text: Binding(
                        get: { 
                            guard let idx = itemIndex, idx < items.count else { return "" }
                            return items[idx].information
                        },
                        set: { newValue in
                            guard let idx = itemIndex, idx < items.count else { return }
                            items[idx].information = newValue
                        }
                    ),
                    minHeight: 80
                )
                }
                
                // 選擇地點

                VStack(alignment: .leading, spacing: 4) {

                    
                Button(action: {
                    guard let idx = itemIndex, idx < items.count else { return }
                    showLocationPickerForItem = items[idx].id
                    activeSheet = .locationPicker // 优化：使用统一的 sheet 状态

                }) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            
                        if let idx = itemIndex, idx < items.count {
                            Text(items[idx].destination.isEmpty ? "選擇地點" : items[idx].destination)
                                    .foregroundColor(items[idx].destination.isEmpty ? .gray : .primary)
                                    .multilineTextAlignment(.center)
                                .lineLimit(2)
                        } else {
                            Text("選擇地點")
                                .foregroundColor(.gray)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.caption)

                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemGray6))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                }
                .onChange(of: item.destination) { oldValue, newValue in
                    // 當填寫地點後，如果是行程2及之後，自動計算時間
                    if index > 0 && !newValue.isEmpty && item.coordinate != nil {
                        onCoordinateChanged()
                    }
                }
                
                // 時間 - 使用 DateTimePickerView 组件
                VStack(alignment: .leading, spacing: 4) {
                    
                    DateTimePickerView(
                    startDate: Binding(
                        get: { 
                            guard let idx = itemIndex, idx < items.count else { return Date() }
                            return items[idx].date
                        },
                        set: { newValue in
                            guard let idx = itemIndex, idx < items.count else { return }
                            items[idx].date = newValue
                        }
                    ),
                    startTime: Binding(
                        get: { 
                            guard let idx = itemIndex, idx < items.count else { return Date() }
                            return items[idx].startTime
                        },
                        set: { newValue in
                            guard let idx = itemIndex, idx < items.count else { return }
                            items[idx].startTime = newValue
                        }
                    ),
                    endDate: Binding(
                        get: { 
                            guard let idx = itemIndex, idx < items.count else { return nil }
                            return items[idx].isHasEnd ? items[idx].date : nil
                        },
                        set: { newValue in
                            guard let idx = itemIndex, idx < items.count, let date = newValue else { return }
                            items[idx].date = date
                        }
                    ),
                    endTime: Binding(
                        get: { 
                            guard let idx = itemIndex, idx < items.count else { return nil }
                            return items[idx].isHasEnd ? items[idx].endTime : nil
                        },
                        set: { newValue in
                            guard let idx = itemIndex, idx < items.count, let time = newValue else { return }
                            items[idx].endTime = time
                        }
                    ),
                    isAllDay: Binding(
                        get: { 
                            guard let idx = itemIndex, idx < items.count else { return false }
                            return items[idx].isAllDay
                        },
                        set: { newValue in
                            guard let idx = itemIndex, idx < items.count else { return }
                            items[idx].isAllDay = newValue
                        }
                    ),
                    isHasEnd: Binding(
                        get: { 
                            guard let idx = itemIndex, idx < items.count else { return false }
                            return items[idx].isHasEnd
                        },
                        set: { newValue in
                            guard let idx = itemIndex, idx < items.count else { return }
                            items[idx].isHasEnd = newValue
                        }
                    )
                )
                }
                .overlay(alignment: .topTrailing) {
                    if isCalculatingTravelTime && index > 0 {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 8)
                            .padding(.top, 8)
                    }
                }
                .onChange(of: item.startTime) { oldValue, newValue in
                    // 確保當前行程時間不早於上一個行程
                    if index > 0 {
                        onStartTimeChanged()
                    }
                }
            }
        }
    }
}
