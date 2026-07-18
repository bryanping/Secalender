//
//  SuggestionInboxView.swift
//  Secalender
//
//  修改内容：Step B — 建議收件匣；本次改版：
//  ① 歸類清晰：AI 建議依來源主題分組（今日安排/待安排/主題名），未排任務依截止日排序，各組可折疊
//  ② 選擇性刪除：勾選後工具列刪除（含確認），單列滑不到的以長按選單刪除
//  ③ 朋友公開活動：拉取好友 openChecked=1 的即將活動，可勾選加入自己的時間表（固定時間，不重排）
//  勾選 → 塞 7 天空檔（朋友活動保留原時間）→ PlanDetailView 預覽 → 套用寫 time_items、來源標記 done。
//

import SwiftUI

struct SuggestionInboxView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @State private var suggestions: [TimeItem] = []
    @State private var floatingTasks: [TimeItem] = []
    @State private var friendEvents: [FriendManager.PublicEventSummary] = []
    // 修改内容：時事活動 — 全域公開活動（世界盃等官方時間線）
    @State private var publicEvents: [PublicEventItem] = []
    @State private var selectedPublicEventIds: Set<String> = []
    @State private var selectedIds: Set<String> = []          // suggestion / task
    @State private var selectedFriendEventIds: Set<String> = []
    @State private var collapsedGroups: Set<String> = []
    @State private var isLoading = true
    @State private var isScheduling = false
    @State private var previewResult: GenerationResult? = nil
    @State private var errorMessage: String? = nil
    @State private var showDeleteConfirm = false

    // MARK: - 分組

    /// AI 建議依 themeKey 分組（顯示友善名稱）
    private var suggestionGroups: [(key: String, title: String, items: [TimeItem])] {
        let grouped = Dictionary(grouping: suggestions) { $0.themeKey ?? "other" }
        return grouped
            .map { (key: $0.key, title: Self.groupTitle(for: $0.key), items: $0.value.sorted { ($0.startAt ?? .distantFuture) < ($1.startAt ?? .distantFuture) }) }
            .sorted { $0.title < $1.title }
    }

    private static func groupTitle(for themeKey: String) -> String {
        switch themeKey {
        case "today_workspace": return "來自今日安排"
        case "suggestion_inbox": return "先前待安排"
        case "travel_planning": return "旅遊規劃"
        case "smart_plan": return "智能規劃"
        case "other": return "其他建議"
        default:
            if themeKey.hasPrefix("custom_") {
                return "主題：" + themeKey.replacingOccurrences(of: "custom_", with: "")
            }
            return themeKey
        }
    }

    private var isEmptyState: Bool {
        suggestions.isEmpty && floatingTasks.isEmpty && friendEvents.isEmpty && publicEvents.isEmpty
    }

    private var totalSelected: Int { selectedIds.count + selectedFriendEventIds.count + selectedPublicEventIds.count }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer(); ProgressView(); Spacer()
                } else if isEmptyState {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // ① AI 建議（依主題分組、可折疊）
                            ForEach(suggestionGroups, id: \.key) { group in
                                collapsibleSection(id: "sg_\(group.key)", title: group.title, count: group.items.count) {
                                    ForEach(group.items, id: \.id) { item in
                                        itemRow(item, subtitle: item.startAt.map { "原建議 \(timeFormatter.string(from: $0))" })
                                    }
                                }
                            }
                            // ② 未排任務（依截止日）
                            if !floatingTasks.isEmpty {
                                collapsibleSection(id: "tasks", title: "未排任務", count: floatingTasks.count) {
                                    ForEach(floatingTasks, id: \.id) { item in
                                        itemRow(item, subtitle: item.deadlineAt.map { "截止 \(timeFormatter.string(from: $0))" })
                                    }
                                }
                            }
                            // ③ 朋友公開活動
                            if !friendEvents.isEmpty {
                                collapsibleSection(id: "friends", title: "朋友公開活動", count: friendEvents.count) {
                                    ForEach(friendEvents) { ev in
                                        friendEventRow(ev)
                                    }
                                }
                            }
                            // 修改内容：時事活動 — 官方公開時間線（世界盃等），勾選以原時間加入
                            if !publicEvents.isEmpty {
                                collapsibleSection(id: "public", title: "時事活動", count: publicEvents.count) {
                                    ForEach(publicEvents) { ev in
                                        publicEventRow(ev)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    bottomBar
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("待安排")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                }
                // 修改内容：選擇性刪除（僅刪自己的建議/任務，朋友活動不可刪）
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !selectedIds.isEmpty {
                        Button(action: { showDeleteConfirm = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    if !isEmptyState {
                        Button(allSelected ? "取消全選" : "全選") { toggleSelectAll() }
                            .font(.subheadline)
                    }
                }
            }
            .task { await load() }
            .alert("刪除所選項目？", isPresented: $showDeleteConfirm) {
                Button("刪除 \(selectedIds.count) 項", role: .destructive) { deleteSelected() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("將從待安排移除，不影響已排入時間表的行程")
            }
            .alert("發生錯誤", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("確定", role: .cancel) { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
            .fullScreenCover(item: $previewResult) { result in
                NavigationView {
                    PlanDetailView(
                        plan: PlanResult(days: [], assumptions: result.assumptions, riskFlags: result.riskFlags),
                        customTitle: "待安排項目",
                        generationResult: result,
                        onDismiss: { previewResult = nil },
                        onRegenerate: {
                            previewResult = nil
                            runSchedule()
                        },
                        onApplied: { markSelectedConsumed() }
                    )
                    .environmentObject(userManager)
                }
            }
        }
    }

    // MARK: - 空狀態
    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)
                Text("目前沒有待安排的項目")
                    .font(.headline)
                Text("在安排預覽頁點「存為建議」，或關注朋友的公開活動，項目會集中到這裡")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            Spacer()
        }
    }

    // MARK: - 可折疊區塊
    private func collapsibleSection<Content: View>(id: String, title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation {
                    if collapsedGroups.contains(id) { collapsedGroups.remove(id) } else { collapsedGroups.insert(id) }
                }
            }) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(8)
                    Spacer()
                    Image(systemName: collapsedGroups.contains(id) ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            if !collapsedGroups.contains(id) {
                content()
            }
        }
    }

    // MARK: - 自有項目列（建議/任務）
    private func itemRow(_ item: TimeItem, subtitle: String?) -> some View {
        let id = item.id ?? ""
        let isSelected = selectedIds.contains(id)
        return Button(action: {
            if isSelected { selectedIds.remove(id) } else { selectedIds.insert(id) }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : Color(UIColor.systemGray3))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("約 \(item.resolvedDurationMin) 分鐘")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.06) : Color(.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color(UIColor.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        // 修改内容：長按單項刪除
        .contextMenu {
            Button(role: .destructive) {
                deleteItems(ids: [id])
            } label: {
                Label("刪除此項", systemImage: "trash")
            }
        }
    }

    // MARK: - 朋友公開活動列（固定時間，套用時不重排）
    private func friendEventRow(_ ev: FriendManager.PublicEventSummary) -> some View {
        let isSelected = selectedFriendEventIds.contains(ev.id)
        return Button(action: {
            if isSelected { selectedFriendEventIds.remove(ev.id) } else { selectedFriendEventIds.insert(ev.id) }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .green : Color(UIColor.systemGray3))
                VStack(alignment: .leading, spacing: 4) {
                    Text(ev.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text("\(ev.friendName) · \(timeFormatter.string(from: ev.startAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let loc = ev.location {
                            Text(loc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding(12)
            .background(isSelected ? Color.green.opacity(0.06) : Color(.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.green.opacity(0.4) : Color(UIColor.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 修改内容：時事活動列（固定時間，套用時不重排）
    private func publicEventRow(_ ev: PublicEventItem) -> some View {
        let isSelected = selectedPublicEventIds.contains(ev.id)
        return Button(action: {
            if isSelected { selectedPublicEventIds.remove(ev.id) } else { selectedPublicEventIds.insert(ev.id) }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .orange : Color(UIColor.systemGray3))
                VStack(alignment: .leading, spacing: 4) {
                    Text(ev.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(timeFormatter.string(from: ev.startAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let loc = ev.location {
                            Text(loc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Image(systemName: "globe.asia.australia.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding(12)
            .background(isSelected ? Color.orange.opacity(0.06) : Color(.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.orange.opacity(0.4) : Color(UIColor.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 底部
    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button(action: runSchedule) {
                HStack {
                    if isScheduling { ProgressView().tint(.white) }
                    Text(totalSelected == 0 ? "選擇要安排的項目" : "排進 7 天內空檔（\(totalSelected)）")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(totalSelected == 0 ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(totalSelected == 0 || isScheduling)
            if !selectedFriendEventIds.isEmpty || !selectedPublicEventIds.isEmpty {
                Text("朋友活動與時事活動將以原時間加入，不重新排程")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
        .overlay(Rectangle().fill(Color(UIColor.systemGray5)).frame(height: 0.5), alignment: .top)
    }

    // MARK: - 全選 / 刪除

    private var allSelected: Bool {
        let allIds = (suggestions + floatingTasks).compactMap(\.id)
        return !allIds.isEmpty && selectedIds.count == allIds.count
            && selectedFriendEventIds.count == friendEvents.count
            && selectedPublicEventIds.count == publicEvents.count
    }

    private func toggleSelectAll() {
        if allSelected {
            selectedIds = []
            selectedFriendEventIds = []
            selectedPublicEventIds = []
        } else {
            selectedIds = Set((suggestions + floatingTasks).compactMap(\.id))
            selectedFriendEventIds = Set(friendEvents.map(\.id))
            selectedPublicEventIds = Set(publicEvents.map(\.id))
        }
    }

    private func deleteSelected() {
        deleteItems(ids: selectedIds)
    }

    private func deleteItems(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        Task {
            for id in ids {
                try? await TimeItemService.shared.delete(itemId: id)
            }
            await MainActor.run { selectedIds.subtract(ids) }
            await load()
        }
    }

    // MARK: - 載入（建議＋任務＋朋友公開活動）
    private func load() async {
        isLoading = true
        do {
            async let s = TimeItemService.shared.fetchSuggestions()
            async let t = TimeItemService.shared.fetchFloatingTasks()
            let (sv, tv) = try await (s, t)

            // 朋友公開活動（失敗靜默；每位朋友最多 5 筆、總量 20 筆）
            var events: [FriendManager.PublicEventSummary] = []
            let uid = await MainActor.run { userManager.userOpenId }
            if !uid.isEmpty {
                let friends = await FriendManager.shared.getFriends(for: uid)
                await withTaskGroup(of: [FriendManager.PublicEventSummary].self) { group in
                    for friend in friends.prefix(20) {
                        group.addTask {
                            await FriendManager.shared.fetchUpcomingPublicEvents(for: friend)
                        }
                    }
                    for await list in group { events.append(contentsOf: list) }
                }
                events = Array(events.sorted { $0.startAt < $1.startAt }.prefix(20))
            }

            // 修改内容：時事活動 — 全域公開活動
            let pubEvents = await PublicEventsService.shared.fetchUpcoming(limit: 20)

            let sortedTasks = tv.sorted { ($0.deadlineAt ?? .distantFuture) < ($1.deadlineAt ?? .distantFuture) }
            await MainActor.run {
                suggestions = sv
                floatingTasks = sortedTasks
                friendEvents = events
                publicEvents = pubEvents
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - 排程：自有項目塞空檔；朋友活動保留原時間 → 統一預覽
    private func runSchedule() {
        let ownSelected = (suggestions + floatingTasks).filter { item in
            guard let id = item.id else { return false }
            return selectedIds.contains(id)
        }
        let friendSelected = friendEvents.filter { selectedFriendEventIds.contains($0.id) }
        let publicSelected = publicEvents.filter { selectedPublicEventIds.contains($0.id) }
        guard !ownSelected.isEmpty || !friendSelected.isEmpty || !publicSelected.isEmpty else { return }
        isScheduling = true
        Task {
            do {
                let cal = Calendar.current
                let rangeStart = Date()
                let rangeEnd = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: Date()))
                    .flatMap { cal.date(bySettingHour: 23, minute: 59, second: 59, of: $0) } ?? Date()
                let existing = try await TimeItemService.shared.fetchFixedItems(rangeStart: rangeStart, rangeEnd: rangeEnd)

                let untimed = ownSelected.map { item in
                    TimeItemCandidate(
                        id: item.id ?? UUID().uuidString,
                        title: item.title,
                        notes: item.notes,
                        durationMin: item.resolvedDurationMin,
                        type: .task
                    )
                }
                let scheduled = GenerationSchedulerService.shared.schedule(
                    untimedCandidates: untimed,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    existingItems: existing
                )
                // 朋友活動：固定時間直通（不重排）
                let fixedCandidates = friendSelected.map { ev in
                    TimeItemCandidate(
                        id: "friend_\(ev.id)",
                        title: "\(ev.title)（與 \(ev.friendName)）",
                        notes: ev.location,
                        startAt: ev.startAt,
                        endAt: ev.endAt,
                        type: .activity,
                        location: ev.location
                    )
                }
                // 修改内容：時事活動 — 亦以原時間直通
                let publicCandidates = publicSelected.map { ev in
                    TimeItemCandidate(
                        id: "public_\(ev.id)",
                        title: ev.title,
                        notes: ev.location,
                        startAt: ev.startAt,
                        endAt: ev.endAt,
                        type: .activity,
                        location: ev.location
                    )
                }
                let allCandidates = scheduled + fixedCandidates + publicCandidates

                var riskFlags: [String] = []
                let unplaced = untimed.count - scheduled.count
                if unplaced > 0 {
                    riskFlags.append("7 天內空檔不足，有 \(unplaced) 項未能排入，可縮短時長或刪減後重試")
                }
                let conflicts = ConflictDetector.shared.detect(candidates: allCandidates, existingItems: existing)

                await MainActor.run {
                    isScheduling = false
                    guard !allCandidates.isEmpty else {
                        errorMessage = "7 天內找不到足夠空檔，請先調整現有行程"
                        return
                    }
                    previewResult = GenerationResult(
                        resultType: .taskOnly,
                        plan: PlanResult(days: [], assumptions: [], riskFlags: riskFlags),
                        candidates: allCandidates,
                        conflicts: conflicts,
                        riskFlags: riskFlags,
                        themeKey: "suggestion_inbox"
                    )
                }
            } catch {
                await MainActor.run {
                    isScheduling = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 套用成功：來源項目標記 done 並刷新（朋友活動無來源需處理）
    private func markSelectedConsumed() {
        let consumed = (suggestions + floatingTasks).filter { item in
            guard let id = item.id else { return false }
            return selectedIds.contains(id)
        }
        Task {
            var updated: [TimeItem] = []
            for var item in consumed {
                item.status = .done
                item.updatedAt = Date()
                updated.append(item)
            }
            try? await TimeItemService.shared.batchUpdate(updated)
            await MainActor.run {
                selectedIds = []
                selectedFriendEventIds = []
                selectedPublicEventIds = []
            }
            await load()
        }
    }
}

#Preview {
    SuggestionInboxView()
        .environmentObject(MockFirebaseUserManager.shared)
}
