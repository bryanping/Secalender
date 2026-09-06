////
//  CalendarView.swift
//  Secalender
//

import SwiftUI
import Foundation
import Firebase
import CoreLocation
import EventKit  // 修改内容：Phase 2-E

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
    @State private var showCreateEvent = false
    @State private var selectedDateForNewEvent: Date?
    @State private var selectedEvent: Event?
    @State private var isLoading = true
    // 修改内容：Step9 — Firestore 讀取節流
    @State private var isRemoteSyncing = false
    @State private var lastSyncedMonthKey: String?
    /// 兩次遠端同步的最小間隔（秒）
    private static let remoteSyncInterval: TimeInterval = 120
    @State private var friendIds: Set<String> = []
    @State private var groupIds: Set<String> = []
    @State private var selectedFilter: EventFilterType = .all
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationPickerManager = LocationPickerManager()  // 用于GPS定位
    
    // 多选模式相关状态（需要在 CalendarView 中管理，因为多个 SharedEventSectionView 需要共享状态）
    @State private var isMultiSelectMode: Bool = false
    @State private var selectedEventIds: Set<Int> = []
    @State private var pendingReloadAfterMultiSelect = false  // 修改内容
    @State private var showBatchShare: Bool = false
    @State private var showMultiEventView: Bool = false
    // 修改内容：Step17 — 右上角「…」直接開啟「日曆管理」頁（頁內含四項功能）
    @State private var showCalendarManagement: Bool = false
    
    /// 搜尋關鍵字（標題、地點、備註、標籤）
    @State private var searchText: String = ""
    /// 依標籤篩選（可選）
    @State private var selectedTagFilter: String? = nil
    /// 修改内容：僅在本頁首次載入時定位到今天，從行程詳情返回不重新定位
    @State private var hasScrolledToToday: Bool = false
    @State private var groupedDays: [(Date, [Event])] = []  // 修改内容：快取分組結果，避免每次勾選重算

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
                        // 修改内容：移除「加載中」ProgressView，避免載入時畫面閃爍
                        LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(groupedDays, id: \.0) { (date, dayEvents) in  // 修改内容
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
                                    .id(calendarDayScrollID(for: date))
                                    .onTapGesture(count: 2) {
                                        selectedDateForNewEvent = date
                                        showCreateEvent = true
                                    }
                                }
                        }
                        .padding(.vertical)
                        .padding(.bottom, 80) // 为TabBar预留空间
                    }
                    .refreshable {
                        // 只在用户主动下拉刷新时才加载
                        await loadEvents(force: true)   // 修改内容：Step9
                    }
                    .task {
                        // 修改内容：Apple 同步 Step6 — 先整理匯入資料（全天正規化／舊資料補紀錄／去重），
                        // 再載入，避免舊的無 id 匯入行程在載入時被覆蓋而無法管理
                        if !userManager.userOpenId.isEmpty {
                            AppleCalendarImportManager.shared.cleanupDuplicates(for: userManager.userOpenId)
                        }
                        // 使用task替代onAppear，只在视图首次出现时加载一次
                        await loadEvents()
                        // 执行GPS定位并保存国家信息
                        await requestGPSLocationAndSaveCountry()
                        // 检查最近行程并计算距离
                        checkUpcomingTripDistance()
                        // 执行自动导入（如果启用）
                        await performAutoImportIfEnabled()
                    }
                    // 修改内容：載入完成後只定位一次
                    .onChange(of: isLoading) { _, loading in
                        if !loading && !hasScrolledToToday {
                            scrollTodayRowToTop(proxy: proxy)
                        }
                    }
                    // 修改内容：從行程詳情返回時不再重新定位
                    .onAppear {
                        if !isLoading && !hasScrolledToToday {
                            scrollTodayRowToTop(proxy: proxy)
                        }
                    }
                    // 修改内容：只在 events / currentMonth 變動時重算分組
                    .onChange(of: events) { _, _ in
                        groupedDays = groupedEventsWithEmptyDays()
                    }
                    .onChange(of: currentMonth) { _, _ in
                        groupedDays = groupedEventsWithEmptyDays()
                    }
                    .onAppear {
                        if groupedDays.isEmpty { groupedDays = groupedEventsWithEmptyDays() }
                    }
                    .onChange(of: selectedFilter) { _, _ in
                        // 当筛选器改变时，重新过滤事件
                        events = filterEvents(allEvents)
                    }
                    .onChange(of: searchText) { _, _ in
                        events = filterEvents(allEvents)
                    }
                    .onChange(of: selectedTagFilter) { _, _ in
                        events = filterEvents(allEvents)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventSaved"))) { _ in
                        // 修改内容：多選中不刷新（背景刪除重送 / 同步會清掉選取狀態），退出多選時補刷新
                        if isMultiSelectMode {
                            pendingReloadAfterMultiSelect = true
                            return
                        }
                        Task { @MainActor in
                            await loadEvents(force: true)   // 修改内容：Step9
                        }
                    }
                    .onChange(of: isMultiSelectMode) { _, on in
                        if !on && pendingReloadAfterMultiSelect {
                            pendingReloadAfterMultiSelect = false
                            Task { @MainActor in await loadEvents(force: true) }
                        }
                    }
                    // 修改内容：Phase 2-E — Apple 日曆變更時觸發自動匯入（Apple→App）
                    .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                        Task { @MainActor in
                            await performAutoImportIfEnabled()
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
                                await loadEvents(force: true)   // 修改内容：Step9
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
            // 修改内容：Step17 — 單一「日曆管理」頁，內含同步日曆／已同步行程／刪除歷史／來源診斷
            .sheet(isPresented: $showCalendarManagement) {
                NavigationStack {
                    CalendarManagementView(showsDoneButton: true)
                        .environmentObject(userManager)
                }
            }
        }
    }

    // MARK: - 数据加载方法
    /// - Parameter force: 是否強制與 Firestore 同步（新增／刪除／下拉刷新時使用）
    private func loadEvents(force: Bool = false) async {
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

        // 1. 先从本地缓存加载事件（立即显示）
        // 修改内容：Step11 — 已刪除（待伺服器確認）者一律不顯示
        let cachedEvents = DeletedEventRegistry.shared.filterDeleted(
            EventCacheManager.shared.loadEvents(for: myId), for: myId
        )
        // 修改内容：time_items 本地快取即時合併 — 剛寫入 / 刪除 / 離線時不等網路即反映
        var quickEvents = cachedEvents.filter { $0.deleted != 1 }
        do {
            let cal = Calendar.current
            let mStart = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth)) ?? currentMonth
            let mEnd = cal.date(byAdding: .month, value: 1, to: mStart) ?? currentMonth
            let rEnd = cal.date(byAdding: .day, value: 7, to: mEnd) ?? mEnd
            let localItems = try await TimeItemService.shared.fetchRanged(rangeStart: mStart, rangeEnd: rEnd, fromCacheOnly: true)
            let localItemIds = Set(localItems.compactMap { $0.id })
            let projected = localItems.compactMap { Event.from(timeItem: $0, creatorOpenid: myId) }
            // 以本地 time_items 為準：移除快取內已不存在的投影，再加入最新投影
            quickEvents = quickEvents.filter { ev in
                guard let tid = ev.timeItemId else { return true }
                return localItemIds.contains(tid)
            }
            let projectedIds = Set(projected.compactMap { $0.id })
            quickEvents.removeAll { ev in ev.timeItemId != nil && projectedIds.contains(ev.id ?? Int.min) }
            quickEvents.append(contentsOf: projected)
            quickEvents = DeletedEventRegistry.shared.filterDeleted(quickEvents, for: myId)
            if !projected.isEmpty || !localItemIds.isEmpty {
                EventCacheManager.shared.saveEvents(quickEvents, for: myId)  // 讓刪除時能在快取找到目標
            }
        } catch {
            print("⚠️ time_items 本地快取讀取失敗: \(error.localizedDescription)")
        }
        if !quickEvents.isEmpty || !cachedEvents.isEmpty {
            let show = quickEvents
            await MainActor.run {
                self.allEvents = show
                self.events = filterEvents(show)
                self.isLoading = false
            }
        }

        // 修改内容：Step9 — Firestore 讀取節流（原本每次刷新都全量重抓，讀取量暴增）
        // 條件：非強制、快取仍新鮮、月份未變、且無同時進行中的同步 → 只用本地快取
        let monthKey = DateFormatter.stable("yyyy-MM").string(from: currentMonth)
        let cacheFresh = EventCacheManager.shared.isCacheValid(for: myId, maxAge: Self.remoteSyncInterval)
        let shouldSkipRemote = !force && cacheFresh && lastSyncedMonthKey == monthKey && !cachedEvents.isEmpty

        if shouldSkipRemote || isRemoteSyncing {
            await MainActor.run { self.isLoading = false }
            if shouldSkipRemote { print("⏭️ 跳過 Firestore 同步（快取仍在 \(Int(Self.remoteSyncInterval)) 秒內）") }
            return
        }

        await MainActor.run { isRemoteSyncing = true }
        defer { Task { @MainActor in isRemoteSyncing = false } }

        // 修改内容：Step11 — 恢復連線後重送離線期間累積的刪除
        EventManager.shared.retryPendingDeletions(for: myId)

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
            
            //    4.1b time_items：新集合（event/suggestion），漸進式遷移
            let cal = Calendar.current
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth)) ?? currentMonth
            let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) ?? currentMonth
            let rangeEnd = cal.date(byAdding: .day, value: 7, to: monthEnd) ?? monthEnd
            let timeItems = (try? await TimeItemService.shared.fetchRanged(rangeStart: monthStart, rangeEnd: rangeEnd)) ?? []
            let timeItemEvents = timeItems.compactMap { Event.from(timeItem: $0, creatorOpenid: myId) }
            allEvents.append(contentsOf: timeItemEvents)
            print("✅ 从 time_items 加载了 \(timeItemEvents.count) 个时间项")
            
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

            // 修改内容：Apple 匯入 Step1 — Apple 匯入行程僅存在本地，
            // 原邏輯以伺服器結果覆蓋快取會使其消失並在下次匯入產生重覆，改為合併保留。
            let localAppleEvents = EventCacheManager.shared
                .loadEvents(for: myId)
                .filter { $0.isAppleImported && $0.deleted != 1 }
            let validAppleIds = AppleCalendarImportManager.shared.importedAppEventIds(for: myId)
            for event in localAppleEvents {
                guard let eventId = event.id, validAppleIds.contains(eventId) else { continue }
                if uniqueEventsDict[eventId] == nil {
                    uniqueEventsDict[eventId] = event
                }
            }

            // 修改内容：Step8 — 內容層去重（仿 Apple 日曆：同一件事只顯示一次）
            // time_items 投影與 users/events 常為同一行程的兩份資料，
            // 依「標題｜日期｜起始時間」收斂，優先保留可編輯的正式事件。
            var bySignature: [String: Event] = [:]
            for event in uniqueEventsDict.values {
                let signature = "\(event.title)|\(event.date)|\((event.isAllDay ?? false) ? "allday" : event.startTime)"
                guard let existing = bySignature[signature] else {
                    bySignature[signature] = event
                    continue
                }
                // 保留順序：正式事件（無 timeItemId）> 有 Apple 來源 > 其他
                let existingRank = existing.timeItemId == nil ? 0 : 1
                let candidateRank = event.timeItemId == nil ? 0 : 1
                if candidateRank < existingRank {
                    bySignature[signature] = event
                }
            }
            // 修改内容：Step11 — 過濾已刪除但尚未被伺服器確認的行程，避免「刪了又回來」
            let uniqueEvents = DeletedEventRegistry.shared.filterDeleted(Array(bySignature.values), for: myId)

            // 6. 更新本地缓存（确保社群事件的 groupId 被正确保存）
            EventCacheManager.shared.saveEvents(uniqueEvents, for: myId)
            print("✅ 已更新本地缓存，包含 \(uniqueEvents.count) 个事件（含社群事件）")

            await MainActor.run {
                self.allEvents = uniqueEvents  // 存储所有事件
                self.friendIds = friendIdSet
                self.groupIds = groupIdSet
                self.events = filterEvents(uniqueEvents)  // 根据当前筛选类型过滤
                self.isLoading = false
                self.lastSyncedMonthKey = monthKey  // 修改内容：Step9 — 記錄已同步月份
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

    /// `ScrollViewReader.scrollTo` 使用的穩定 id，對應當月某一天。
    private func calendarDayScrollID(for date: Date) -> String {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        let y = cal.component(.year, from: d)
        let m = cal.component(.month, from: d)
        let day = cal.component(.day, from: d)
        return "calendarDay-\(y)-\(m)-\(day)"
    }

    /// 當前檢視月份包含「今天」時，將該日區塊捲至頂部。
    private func scrollTodayRowToTop(proxy: ScrollViewProxy) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard cal.isDate(today, equalTo: currentMonth, toGranularity: .month) else { return }
        let id = calendarDayScrollID(for: today)
        hasScrolledToToday = true   // 修改内容
        // 修改内容：不使用動畫，直接定位，避免出現從 1 號捲動到今天的過程
        proxy.scrollTo(id, anchor: .top)
        DispatchQueue.main.async {
            proxy.scrollTo(id, anchor: .top)
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
                // 修改内容：Step17 — 右上角「…」開啟日曆管理
                Button {
                    showCalendarManagement = true
                } label: {
                    Image(systemName: "ellipsis.circle")
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
    
    /// 當前事件中出現過的所有標籤（用於篩選）
    private var allDistinctTags: [String] {
        var set: Set<String> = []
        for event in allEvents {
            (event.tags ?? []).forEach { set.insert($0) }
        }
        return EventTagPresets.tagKeys.filter { set.contains($0) }
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

        // 修改内容：Phase 2-B — 展開重複事件（母事件 + 當月範圍內的 occurrence）
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? startOfMonth
        let rawExpanded = events.flatMap { ev -> [Event] in
            guard ev.deleted != 1 else { return [ev] }
            return [ev] + ev.occurrences(from: startOfMonth, to: endOfMonth, calendar: calendar)
        }

        // 修改内容：Step18 — 展開後去重
        // ① 同一系列（同 appleEventId）同一天只顯示一次
        // ② 生日這類每年重複的行程，Apple 每年標題不同（33 歲／43 歲），
        //    以「去除數字後的標題 + 日期」再收斂一次，避免同日並列多個年份版本
        var seenExpanded = Set<String>()
        var expandedEvents: [Event] = []
        for event in rawExpanded {
            let seriesKey: String
            if let appleId = event.appleEventId {
                seriesKey = "apple|\(appleId)|\(event.date)"
            } else {
                seriesKey = "local|\(event.id ?? 0)|\(event.date)"
            }
            let titleKey = "title|" + event.title.filter { !$0.isNumber } + "|\(event.date)|\((event.isAllDay ?? false) ? "allday" : event.startTime)"

            if seenExpanded.contains(seriesKey) || seenExpanded.contains(titleKey) { continue }
            seenExpanded.insert(seriesKey)
            seenExpanded.insert(titleKey)
            expandedEvents.append(event)
        }

        // 过滤当前月份的事件
        let monthEvents = expandedEvents.compactMap { event -> Event? in
            // 跳过已删除的事件
            if event.deleted == 1 {
                return nil
            }
            
            guard let dateObj = event.dateObj else {
                return nil // 如果日期解析失败，跳过该事件
            }
            
            // 修改内容：Phase 1-B — 原判斷只看「開始日」是否在當月，
            // 上月開始、跨入本月的多日事件在本月完全不顯示。
            // 改為：事件的 [開始日, 結束日] 區間與當月有交集即納入。
            let startDay = calendar.startOfDay(for: dateObj)
            let endDay = calendar.startOfDay(for: event.endDateObj ?? dateObj)
            let isInCurrentMonth = calendar.isDate(startDay, equalTo: currentMonth, toGranularity: .month)
                || calendar.isDate(endDay, equalTo: currentMonth, toGranularity: .month)
                || (startDay < startOfMonth && endDay >= startOfMonth)
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
    /// 根据选中的筛选类型、搜尋關鍵字、標籤過濾事件
    private func filterEvents(_ eventsToFilter: [Event]) -> [Event] {
        let myId = userManager.userOpenId
        var result: [Event]
        
        switch selectedFilter {
        case .all:
            result = eventsToFilter
        case .myOwn:
            result = eventsToFilter.filter { $0.creatorOpenid == myId }
        case .friendAndPublic:
            result = eventsToFilter.filter { event in
                if let groupId = event.groupId, groupIds.contains(groupId) { return true }
                if event.creatorOpenid == myId { return false }
                if friendIds.contains(event.creatorOpenid) && event.openChecked == 1 { return true }
                return false
            }
        case .nearby:
            guard locationManager.currentLocation != nil else { return [] }
            result = eventsToFilter.filter { event in
                event.openChecked == 1 && !event.destination.isEmpty
            }
        }
        
        // 搜尋：標題、地點、備註、標籤
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { event in
                event.title.lowercased().contains(query) ||
                event.destination.lowercased().contains(query) ||
                (event.information?.lowercased().contains(query) ?? false) ||
                (event.tags?.contains { $0.lowercased().contains(query) } ?? false)
            }
        }
        
        // 標籤篩選
        if let tag = selectedTagFilter {
            result = result.filter { ($0.tags ?? []).contains(tag) }
        }
        
        return result
    }
    
    /// 从 Firestore 文档解析 Event（与 EventManager 中的方法保持一致）
    nonisolated private func parseEventFromDocument(_ document: QueryDocumentSnapshot) -> Event? {
        let data = document.data()
        
        // 手动解析，处理缺失字段和类型不匹配
        var event = Event()
        
        // 基本字段
        event.id = data["id"] as? Int ?? document.documentID.stableIntId  // 修改内容：P0-3 穩定雜湊
        EventDocumentIndex.shared.record(eventId: event.id, path: document.reference.path)  // 修改内容：Step10
        event.title = data["title"] as? String ?? ""
        event.creatorOpenid = data["creatorOpenid"] as? String ?? ""
        event.color = data["color"] as? String ?? "#FF0000" // 默认红色
        
        // 处理date字段：可能是String或Timestamp
        if let dateString = data["date"] as? String {
            event.date = dateString
        } else if let timestamp = data["date"] as? Timestamp {
            let formatter = DateFormatter.stable("yyyy-MM-dd")
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
        event.aiEvent = data["aiEvent"] as? Int ?? 0
        event.tags = data["tags"] as? [String]
        
        return event
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
                  parseCoordinate(from: event.mapObj) != nil else {
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

        // 修改内容：Apple 匯入 Step4 — 每次啟動先清理重複／舊版殘留的匯入行程
        if AppleCalendarImportManager.shared.cleanupDuplicates(for: userManager.userOpenId) > 0 {
            await loadEvents()
        }

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
        // 修改内容：Phase 1-A — 儲存字串一律走 stable
        return DateFormatter.stable(format).string(from: self)
    }
}


struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
