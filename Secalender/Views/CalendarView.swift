////
//  CalendarView.swift
//  Secalender
//

import SwiftUI
import Foundation
import Firebase
import CoreLocation

/// 行程筛选类型
enum EventFilterType: String, CaseIterable {
    case all = "全部"
    case myOwn = "我的行程"
    case friendAndPublic = "朋友＆社群"
    case nearby = "附近行程"
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .myOwn: return "person.fill"
        case .friendAndPublic: return "person.2.fill"
        case .nearby: return "location.fill"
        }
    }
    
    /// 本地化显示名称
    @MainActor
    var localizedDisplayName: String {
        switch self {
        case .all: return "calendar.filter.all".localized()
        case .myOwn: return "calendar.filter.my_own".localized()
        case .friendAndPublic: return "calendar.filter.friend_and_public".localized()
        case .nearby: return "calendar.filter.nearby".localized()
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var currentMonth: Date = Date()
    @State private var events: [Event] = []
    @State private var allEvents: [Event] = []  // 存储所有事件
    @State private var scrollToDate: Date?
    @State private var showCreateEvent = false
    @State private var selectedDateForNewEvent: Date?
    @State private var selectedEvent: Event?
    @State private var isLoading = true
    @State private var friendIds: Set<String> = []
    @State private var groupIds: Set<String> = []
    @State private var selectedFilter: EventFilterType = .all
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationPickerManager = LocationPickerManager()  // 用于GPS定位
    
    // 多选模式相关状态（需要在 CalendarView 中管理，因为多个 SharedEventSectionView 需要共享状态）
    @State private var isMultiSelectMode: Bool = false
    @State private var selectedEventIds: Set<Int> = []
    @State private var showBatchShare: Bool = false
    @State private var showMultiEventView: Bool = false
    @State private var showImportAppleCalendar: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                Divider()
                // 筛选标签栏
                filterTabBar
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        if isLoading {
                            ProgressView("加载中...")
                                .padding()
                        } else {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(groupedEventsWithEmptyDays(), id: \.0) { (date, dayEvents) in
                                    SharedEventSectionView(
                                        date: date,
                                        events: dayEvents,
                                        currentUserOpenid: userManager.userOpenId,
                                        allowNavigation: !isMultiSelectMode, // 多选模式下禁用导航
                                        onEventUpdated: {
                                            Task { @MainActor in
                                                await loadEvents()
                                            }
                                        },
                                        friendIds: friendIds,
                                        groupIds: groupIds,
                                        isMultiSelectMode: $isMultiSelectMode,
                                        selectedEventIds: $selectedEventIds
                                    )
                                    .onTapGesture(count: 2) {
                                        selectedDateForNewEvent = date
                                        showCreateEvent = true
                                    }
                                }
                            }
                            .padding(.vertical)
                            .padding(.bottom, 80) // 为TabBar预留空间
                        }
                    }
                    .refreshable {
                        // 只在用户主动下拉刷新时才加载
                        await loadEvents(proxy: proxy)
                    }
                    .task {
                        // 使用task替代onAppear，只在视图首次出现时加载一次
                        await loadEvents(proxy: proxy)
                        // 执行GPS定位并保存国家信息
                        await requestGPSLocationAndSaveCountry()
                        // 检查最近行程并计算距离
                        checkUpcomingTripDistance()
                        // 执行自动导入（如果启用）
                        await performAutoImportIfEnabled()
                    }
                    .onChange(of: selectedFilter) { _ in
                        // 当筛选器改变时，重新过滤事件
                        events = filterEvents(allEvents)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventSaved"))) { _ in
                        // 当事件保存完成后，刷新事件列表
                        Task { @MainActor in
                            await loadEvents()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // 多选模式工具栏
                if isMultiSelectMode {
                    multiSelectToolbar
                }
            }
            .sheet(isPresented: $showCreateEvent) {
                NavigationView {
                    EventCreateView(
                        viewModel: EventDetailViewModel(
                            event: Event(
                                date: selectedDateForNewEvent?.toString() ?? "",
                                startTime: "09:00:00",
                                endTime: "10:00:00"
                            )
                        ),
                        onComplete: {
                            self.showCreateEvent = false
                            // 只在保存成功后刷新，避免频繁刷新
                            Task { @MainActor in
                                await loadEvents()
                            }
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .sheet(isPresented: $showBatchShare) {
                NavigationView {
                    BatchShareEventsView(
                        eventIds: Array(selectedEventIds),
                        allEvents: allEvents,
                        onComplete: {
                            showBatchShare = false
                            isMultiSelectMode = false
                            selectedEventIds.removeAll()
                            Task { @MainActor in
                                await loadEvents()
                            }
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .sheet(isPresented: $showMultiEventView) {
                NavigationView {
                    MultiEventView(
                        eventIds: Array(selectedEventIds),
                        allEvents: $allEvents,  // 传递 Binding
                        onComplete: {
                            // 完成操作后不关闭页面，保持在多行程检视页面
                        },
                        onRefreshEvents: {
                            // 刷新事件列表
                            await loadEvents()
                        },
                        onDismiss: {
                            // 关闭页面时刷新行程并取消多选状态
                            Task { @MainActor in
                                await loadEvents()
                                // 重置多选状态
                                withAnimation {
                                    isMultiSelectMode = false
                                    selectedEventIds.removeAll()
                                }
                            }
                        }
                    )
                    .environmentObject(userManager)
                }
            }
            .sheet(isPresented: $showImportAppleCalendar) {
                ImportAppleCalendarView()
                    .environmentObject(userManager)
            }
        }
    }

    // MARK: - 数据加载方法
    private func loadEvents(proxy: ScrollViewProxy? = nil) async {
        await MainActor.run {
            isLoading = true
        }

        guard !userManager.userOpenId.isEmpty else {
            await MainActor.run {
                isLoading = false
            }
            return
        }

        let myId = userManager.userOpenId
        let role = userManager.userRole
        
        // 1. 先从本地缓存加载事件（立即显示）
        let cachedEvents = EventCacheManager.shared.loadEvents(for: myId)
        if !cachedEvents.isEmpty {
            await MainActor.run {
                // 先显示缓存的数据
                self.allEvents = cachedEvents.filter { $0.deleted != 1 }
                self.events = filterEvents(self.allEvents)
                self.isLoading = false
            }
        }
        
        do {
            let db = Firestore.firestore()
            var allEvents: [Event] = []
            
            // 2. 加载好友列表
            await FriendManager.shared.loadFriends(for: myId)
            let friendIdSet = FriendManager.shared.getFriendIds()
            
            // 3. 加载用户加入的社群列表
            let groupSnapshot = try await db.collection("groups")
                .whereField("members", arrayContains: myId)
                .getDocuments()
            let groupIdSet = Set(groupSnapshot.documents.map { $0.documentID })
            
            // 4. 根据新的存储逻辑拉取事件：
            //    4.1 个人行程：从 users/{myId}/events 拉取（自己创建的）
            let myEventsSnapshot = try await db.collection("users")
                .document(myId)
                .collection("events")
                .getDocuments()
            
            let myOwnEvents = myEventsSnapshot.documents.compactMap { document -> Event? in
                return parseEventFromDocument(document)
            }.filter { $0.deleted != 1 }
            
            allEvents.append(contentsOf: myOwnEvents)
            print("✅ 从 users/\(myId)/events 加载了 \(myOwnEvents.count) 个个人事件")
            
            //    4.2 好友公开行程：从每个好友的 users/{friendId}/events 拉取（openChecked == 1）
            // 修改内容：使用并行查询代替串行循环，提升性能
            var friendSharedEvents: [Event] = []
            if !friendIdSet.isEmpty {
                try await withThrowingTaskGroup(of: [Event].self) { group in
                    for friendId in friendIdSet {
                        group.addTask {
                            do {
                                let friendEventsSnapshot = try await db.collection("users")
                                    .document(friendId)
                                    .collection("events")
                                    .whereField("openChecked", isEqualTo: 1)  // 只拉取公开的事件
                                    .getDocuments()
                                
                                let friendEvents = friendEventsSnapshot.documents.compactMap { document -> Event? in
                                    return parseEventFromDocument(document)
                                }.filter { $0.deleted != 1 && $0.creatorOpenid == friendId }  // 确保是好友创建的
                                
                                return friendEvents
                            } catch {
                                print("⚠️ 加载好友 \(friendId) 的事件失败: \(error.localizedDescription)")
                                return []
                            }
                        }
                    }
                    
                    for try await friendEvents in group {
                        friendSharedEvents.append(contentsOf: friendEvents)
                    }
                }
            }
            
            allEvents.append(contentsOf: friendSharedEvents)
            print("✅ 从好友的 events 加载了 \(friendSharedEvents.count) 个好友公开事件")
            
            //    4.3 社群行程：从 groups/{groupId}/groupEvents 拉取（用户加入的社群）
            // 修改内容：使用并行查询代替串行循环，提升性能
            var groupSharedEvents: [Event] = []
            if !groupIdSet.isEmpty {
                try await withThrowingTaskGroup(of: [Event].self) { group in
                    for groupId in groupIdSet {
                        group.addTask {
                            do {
                                let groupEventsSnapshot = try await db.collection("groups")
                                    .document(groupId)
                                    .collection("groupEvents")
                                    .getDocuments()
                                
                                let groupEvents = groupEventsSnapshot.documents.compactMap { document -> Event? in
                                    return parseEventFromDocument(document)
                                }.filter { $0.deleted != 1 }
                                
                                return groupEvents
                            } catch {
                                print("⚠️ 加载社群 \(groupId) 的事件失败: \(error.localizedDescription)")
                                return []
                            }
                        }
                    }
                    
                    for try await groupEvents in group {
                        groupSharedEvents.append(contentsOf: groupEvents)
                    }
                }
            }
            
            allEvents.append(contentsOf: groupSharedEvents)
            print("✅ 从社群的 groupEvents 加载了 \(groupSharedEvents.count) 个社群事件")
            
            // 5. 按ID去重（可能有重复的事件）
            var uniqueEventsDict: [Int: Event] = [:]
            for event in allEvents {
                if let eventId = event.id {
                    uniqueEventsDict[eventId] = event
                }
            }
            let uniqueEvents = Array(uniqueEventsDict.values)

            // 6. 更新本地缓存（确保社群事件的 groupId 被正确保存）
            EventCacheManager.shared.saveEvents(uniqueEvents, for: myId)
            print("✅ 已更新本地缓存，包含 \(uniqueEvents.count) 个事件（含社群事件）")

            await MainActor.run {
                self.allEvents = uniqueEvents  // 存储所有事件
                self.friendIds = friendIdSet
                self.groupIds = groupIdSet
                self.events = filterEvents(uniqueEvents)  // 根据当前筛选类型过滤
                self.scrollToDate = Calendar.current.startOfDay(for: Date())
                self.isLoading = false
            }

        } catch {
            print("⚠️ Firebase加载失败，使用本地缓存: \(error.localizedDescription)")
            // 如果Firebase失败，使用本地缓存
            let cachedEvents = EventCacheManager.shared.loadEvents(for: myId)
            let activeCachedEvents = cachedEvents.filter { $0.deleted != 1 }
            
            await MainActor.run {
                if !activeCachedEvents.isEmpty {
                    self.allEvents = activeCachedEvents
                    self.events = filterEvents(activeCachedEvents)
                }
                self.isLoading = false
            }
        }
    }

    private var headerView: some View {
        HStack {
            // 多选模式下显示退出按钮
            if isMultiSelectMode {
                Button {
                    withAnimation {
                        isMultiSelectMode = false
                        selectedEventIds.removeAll()
                    }
                } label: {
                    Text("calendar.cancel".localized())
                        .foregroundColor(.blue)
                }
            } else {
                Spacer()
            }
            
            Spacer()
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
            }
            Text(monthFormatter.string(from: currentMonth))
                .font(.headline)
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
            }
            Spacer()
            
            // 多选模式下显示分享和编辑按钮，否则显示+号和导入按钮
            if isMultiSelectMode {
                // 编辑按钮
                Button {
                    if !selectedEventIds.isEmpty {
                        showMultiEventView = true
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.blue)
                }
                .disabled(selectedEventIds.isEmpty)
                
                // 分享按钮
                Button {
                    if !selectedEventIds.isEmpty {
                        showBatchShare = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .disabled(selectedEventIds.isEmpty)
            } else {
                // 导入 Apple 日历按钮
                Button {
                    showImportAppleCalendar = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                }
                
                // 创建事件按钮
//                Button {
//                    selectedDateForNewEvent = Date()
//                    showCreateEvent = true
//                } label: {
//                    Image(systemName: "plus.circle")
//                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // 筛选标签栏
    private var filterTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(EventFilterType.allCases, id: \.self) { filterType in
                    Button(action: {
                        withAnimation {
                            selectedFilter = filterType
                            events = filterEvents(allEvents)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: filterType.icon)
                                .font(.system(size: 12))
                            Text(filterType.localizedDisplayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(selectedFilter == filterType ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedFilter == filterType ? Color.blue : Color.gray.opacity(0.2))
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)!
        Task { @MainActor in
            await loadEvents()
        }
    }

    private func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)!
        Task { @MainActor in
            await loadEvents()
        }
    }

    private func groupedEventsWithEmptyDays() -> [(Date, [Event])] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let startOfMonth = calendar.date(from: components)!

        var result: [(Date, [Event])] = []

        // 过滤当前月份的事件
        let monthEvents = events.compactMap { event -> Event? in
            // 跳过已删除的事件
            if event.deleted == 1 {
                return nil
            }
            
            guard let dateObj = event.dateObj else {
                return nil // 如果日期解析失败，跳过该事件
            }
            
            // 只返回当前月份的事件
            let isInCurrentMonth = calendar.isDate(dateObj, equalTo: currentMonth, toGranularity: .month)
            return isInCurrentMonth ? event : nil
        }

        var eventDict: [Date: [Event]] = [:]
        for event in monthEvents {
            guard let dateObj = event.dateObj else { continue }
            let startDay = calendar.startOfDay(for: dateObj)
            if event.isMultiDay, let endDateObj = event.endDateObj {
                let endDay = calendar.startOfDay(for: endDateObj)
                var current = startDay
                while current <= endDay {
                    if calendar.isDate(current, equalTo: currentMonth, toGranularity: .month) {
                        if eventDict[current] == nil { eventDict[current] = [] }
                        eventDict[current]?.append(event)
                    }
                    current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
                }
            } else {
                if eventDict[startDay] == nil { eventDict[startDay] = [] }
                eventDict[startDay]?.append(event)
            }
        }

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let normalizedDate = calendar.startOfDay(for: date)
                let dayEvents = eventDict[normalizedDate] ?? []
                result.append((date, dayEvents))
            }
        }

        return result
    }
    
    // MARK: - 事件筛选方法
    /// 根据选中的筛选类型过滤事件（按照新的存储逻辑）
    private func filterEvents(_ eventsToFilter: [Event]) -> [Event] {
        let myId = userManager.userOpenId
        
        switch selectedFilter {
        case .all:
            // 返回所有事件（个人、好友公开、社群）
            return eventsToFilter
            
        case .myOwn:
            // 只返回自己创建的事件（来自 users/{myId}/events，无论是否有 groupId）
            return eventsToFilter.filter { $0.creatorOpenid == myId }
            
        case .friendAndPublic:
            // 返回朋友分享的事件或社群事件
            // 优先级：社群活动优先（即使自己创建的社群活动也要显示）
            return eventsToFilter.filter { event in
                // 1. 社群事件（优先判断）- 包括自己创建的社群活动
                // 社群活动应该显示为蓝色，即使创建者是自己
                if let groupId = event.groupId, groupIds.contains(groupId) {
                    return true
                }
                
                // 2. 排除自己创建的个人活动（非社群活动）
                if event.creatorOpenid == myId {
                    return false  // 排除自己创建的个人活动
                }
                
                // 3. 好友公开的事件（来自 users/{friendId}/events，openChecked == 1）
                if friendIds.contains(event.creatorOpenid) && event.openChecked == 1 {
                    return true
                }
                
                return false
            }
            
        case .nearby:
            // 附近行程：基于用户位置筛选
            guard let userLocation = locationManager.currentLocation else {
                // 如果无法获取位置，返回空数组
                return []
            }
            
            return eventsToFilter.filter { event in
                // 如果事件有地点信息，计算距离
                if !event.destination.isEmpty {
                    // 这里可以添加基于mapObj的距离计算
                    // 暂时返回所有有地点信息且公开的事件
                    return event.openChecked == 1 && !event.destination.isEmpty
                }
                return false
            }
        }
    }
    
    /// 从 Firestore 文档解析 Event（与 EventManager 中的方法保持一致）
    private func parseEventFromDocument(_ document: QueryDocumentSnapshot) -> Event? {
        do {
            let data = document.data()
            
            // 手动解析，处理缺失字段和类型不匹配
            var event = Event()
            
            // 基本字段
            event.id = data["id"] as? Int ?? abs(document.documentID.hashValue)
            event.title = data["title"] as? String ?? ""
            event.creatorOpenid = data["creatorOpenid"] as? String ?? ""
            event.color = data["color"] as? String ?? "#FF0000" // 默认红色
            
            // 处理date字段：可能是String或Timestamp
            if let dateString = data["date"] as? String {
                event.date = dateString
            } else if let timestamp = data["date"] as? Timestamp {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                event.date = formatter.string(from: timestamp.dateValue())
            } else {
                event.date = ""
            }
            
            event.startTime = data["startTime"] as? String ?? ""
            event.endTime = data["endTime"] as? String ?? ""
            event.endDate = data["endDate"] as? String
            event.destination = data["destination"] as? String ?? ""
            event.mapObj = data["mapObj"] as? String ?? ""
            event.openChecked = data["openChecked"] as? Int ?? 0
            event.personChecked = data["personChecked"] as? Int ?? 0
            event.personNumber = data["personNumber"] as? Int
            event.sponsorType = data["sponsorType"] as? String
            event.category = data["category"] as? String
            event.createTime = data["createTime"] as? String ?? ""
            event.deleted = data["deleted"] as? Int
            event.information = data["information"] as? String
            event.groupId = data["groupId"] as? String
            event.isAllDay = data["isAllDay"] as? Bool ?? false
            event.repeatType = data["repeatType"] as? String ?? "never"
            event.calendarComponent = data["calendarComponent"] as? String ?? "default"
            event.travelTime = data["travelTime"] as? String
            event.invitees = data["invitees"] as? [String]
            
            return event
        } catch {
            print("解析事件失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 多选模式工具栏
    private var multiSelectToolbar: some View {
        HStack(spacing: 16) {
            Button("取消") {
                isMultiSelectMode = false
                selectedEventIds.removeAll()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Text("calendar.selected_events_count".localized(with: selectedEventIds.count))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                if !selectedEventIds.isEmpty {
                    showBatchShare = true
                }
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedEventIds.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
    }
    
    // MARK: - GPS定位和国家保存
    /// 执行GPS定位并保存国家信息
    @MainActor
    private func requestGPSLocationAndSaveCountry() async {
        // 先尝试从缓存加载国家信息
        if let cachedCountry = LocationCacheManager.shared.loadUserCountry() {
            print("✅ 已从缓存加载用户所在国家: \(cachedCountry)")
            return
        }
        
        // 先尝试从缓存加载位置
        if let cachedCoordinate = LocationCacheManager.shared.loadLastLocation() {
            let cachedLocation = CLLocation(latitude: cachedCoordinate.latitude, longitude: cachedCoordinate.longitude)
            await reverseGeocodeAndSaveCountry(location: cachedLocation)
            return
        }
        
        // 请求位置权限
        locationPickerManager.requestPermission()
        
        // 异步获取位置
        // 等待位置更新（最多等待5秒）
        let startTime = Date()
        while locationPickerManager.currentLocation == nil && Date().timeIntervalSince(startTime) < 5.0 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }
        
        if let location = locationPickerManager.currentLocation {
            LocationCacheManager.shared.saveLastLocation(location)
            await reverseGeocodeAndSaveCountry(location: location)
        } else {
            // 尝试一次性定位
            if let location = await locationPickerManager.requestLocationOnce() {
                LocationCacheManager.shared.saveLastLocation(location)
                await reverseGeocodeAndSaveCountry(location: location)
            } else {
                print("⚠️ GPS定位失败，无法获取用户所在国家")
            }
        }
    }
    
    /// 反向地理编码并保存国家信息
    private func reverseGeocodeAndSaveCountry(location: CLLocation) async {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first,
               let country = placemark.country {
                // 转换为中文国家名
                if let chineseCountry = convertCountryToChinese(country) {
                    LocationCacheManager.shared.saveUserCountry(chineseCountry)
                    print("✅ 已保存用户所在国家: \(chineseCountry) (原始: \(country))")
                } else {
                    print("⚠️ 无法将国家名转换为中文: \(country)")
                }
            }
        } catch {
            print("⚠️ 反向地理编码失败: \(error.localizedDescription)")
        }
    }
    
    /// 国家名称转换（英文转中文）
    private func convertCountryToChinese(_ englishCountry: String) -> String? {
        let dataManager = DestinationDataManager.shared
        let allCountries = dataManager.getAllCountries()
        
        // 先尝试直接搜索（支持简繁体英文）
        let matchedCountries = dataManager.searchCountries(englishCountry)
        if let matchedCountry = matchedCountries.first {
            return matchedCountry
        }
        
        // 如果搜索不到，返回nil
        return nil
    }
    
    // MARK: - 检查最近行程距离
    /// 检查最近行程并计算距离，提醒出发
    private func checkUpcomingTripDistance() {
        guard let userLocation = locationManager.currentLocation else {
            // 如果没有用户位置，尝试从缓存加载
            if let cachedCoordinate = LocationCacheManager.shared.loadLastLocation() {
                let cachedLocation = CLLocation(latitude: cachedCoordinate.latitude, longitude: cachedCoordinate.longitude)
                calculateDistanceToUpcomingTrips(from: cachedLocation)
            } else {
                print("⚠️ 无法获取用户位置，无法计算行程距离")
            }
            return
        }
        
        calculateDistanceToUpcomingTrips(from: userLocation)
    }
    
    /// 计算用户位置到最近行程的距离
    private func calculateDistanceToUpcomingTrips(from userLocation: CLLocation) {
        let now = Date()
        let calendar = Calendar.current
        
        // 查找未来7天内的行程
        let upcomingEvents = allEvents.filter { event in
            guard let eventDate = event.dateObj,
                  event.deleted != 1,
                  !event.destination.isEmpty,
                  let eventCoordinate = parseCoordinate(from: event.mapObj) else {
                return false
            }
            
            // 只检查未来7天内的行程
            let daysUntilEvent = calendar.dateComponents([.day], from: now, to: eventDate).day ?? 0
            return daysUntilEvent >= 0 && daysUntilEvent <= 7
        }
        
        // 按日期排序，找到最近的行程
        let sortedEvents = upcomingEvents.sorted { event1, event2 in
            guard let date1 = event1.dateObj,
                  let date2 = event2.dateObj else {
                return false
            }
            return date1 < date2
        }
        
        guard let nearestEvent = sortedEvents.first,
              let eventCoordinate = parseCoordinate(from: nearestEvent.mapObj) else {
            return
        }
        
        let eventLocation = CLLocation(latitude: eventCoordinate.latitude, longitude: eventCoordinate.longitude)
        let distance = userLocation.distance(from: eventLocation) // 米
        let distanceKm = distance / 1000.0 // 公里
        
        // 计算距离事件还有多少天
        guard let eventDate = nearestEvent.dateObj else { return }
        let daysUntilEvent = calendar.dateComponents([.day], from: now, to: eventDate).day ?? 0
        
        // 如果距离超过100公里，且还有时间，提醒用户
        if distanceKm > 100 && daysUntilEvent > 0 {
            print("📍 提醒：最近的行程「\(nearestEvent.title)」距离您 \(String(format: "%.1f", distanceKm)) 公里，还有 \(daysUntilEvent) 天")
            // 这里可以添加通知或UI提示
        } else if distanceKm > 100 && daysUntilEvent == 0 {
            print("📍 提醒：今天的行程「\(nearestEvent.title)」距离您 \(String(format: "%.1f", distanceKm)) 公里，请提前出发")
        }
    }
    
    /// 从 mapObj JSON 字符串中解析坐标
    private func parseCoordinate(from mapObj: String) -> CLLocationCoordinate2D? {
        guard !mapObj.isEmpty,
              let jsonData = mapObj.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let latitude = json["latitude"] as? Double,
              let longitude = json["longitude"] as? Double else {
            return nil
        }
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 如果启用自动导入，则执行自动导入
    @MainActor
    private func performAutoImportIfEnabled() async {
        guard !userManager.userOpenId.isEmpty else { return }
        
        // 检查是否启用自动导入
        guard UserPreferencesManager.shared.getAutoImportAppleCalendar(for: userManager.userOpenId) else {
            return
        }
        
        // 执行自动导入（在后台进行，不阻塞UI）
        Task {
            let count = await AppleCalendarImportManager.shared.performAutoImport(
                for: userManager.userOpenId,
                lookAheadDays: 30
            )
            if count > 0 {
                // 如果有新事件导入，刷新事件列表
                await loadEvents()
            }
        }
    }
}

// MARK: - 位置管理器
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置获取失败: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

private let monthFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy · MM"
    return f
}()

extension Date {
    func toString(format: String = "yyyy-MM-dd") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}


struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
