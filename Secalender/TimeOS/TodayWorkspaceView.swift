//
//  TodayWorkspaceView.swift
//  Secalender
//
//  修改内容：Step C — 今日工作台（「安排今天」的真差異化版本：零輸入、context-first）
//  進入即讀取今天的 time_items：顯示「N 個行程 · 空檔 M 小時」＋今日時間軸（行程與空檔交錯）。
//  下方待安排（建議池＋未排任務＋臨時快速新增）勾選 → 塞進今天剩餘空檔 → PlanDetailView 統一預覽 → 套用寫 time_items。
//

import SwiftUI

struct TodayWorkspaceView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    // 今日資料
    @State private var fixedItems: [TimeItem] = []
    @State private var gaps: [GenerationTimeSlot] = []
    // 待安排來源
    @State private var suggestions: [TimeItem] = []
    @State private var floatingTasks: [TimeItem] = []
    @State private var selectedIds: Set<String> = []
    // 臨時快速新增（僅本次，不落庫；套用時直接成為 event）
    @State private var quickAddTitle: String = ""
    @State private var quickAddDuration: Int = 60
    @State private var quickItems: [(id: String, title: String, durationMin: Int)] = []
    @State private var selectedQuickIds: Set<String> = []

    @State private var isLoading = true
    @State private var isScheduling = false
    @State private var previewResult: GenerationResult? = nil
    @State private var errorMessage: String? = nil

    private var freeMinutes: Int { gaps.reduce(0) { $0 + $1.durationMin } }
    private var selectedCount: Int { selectedIds.count + selectedQuickIds.count }

    /// 今日排程視窗：現在 → 22:00（過 22:00 則到 23:59）
    private var scheduleWindow: (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        let dayStart = cal.startOfDay(for: now)
        var end = cal.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart) ?? now
        if now >= end {
            end = cal.date(bySettingHour: 23, minute: 59, second: 0, of: dayStart) ?? now
        }
        return (max(now, dayStart), end)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer(); ProgressView(); Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            headerSummary
                            timelineSection
                            pendingSection
                            quickAddSection
                            Spacer().frame(height: 12)
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.interactively)

                    bottomBar
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("安排今天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .task { await load() }
            .alert("發生錯誤", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("確定", role: .cancel) { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
            .fullScreenCover(item: $previewResult) { result in
                NavigationView {
                    PlanDetailView(
                        plan: PlanResult(days: [], assumptions: [], riskFlags: result.riskFlags),
                        customTitle: "今天的安排",
                        generationResult: result,
                        onDismiss: { previewResult = nil },
                        onRegenerate: {
                            previewResult = nil
                            runSchedule()
                        },
                        onApplied: { outcome in markConsumedAndReload(outcome) }  // 修改內容：只消耗實際寫入成功的項目
                    )
                    .environmentObject(userManager)
                }
            }
        }
    }

    // MARK: - 摘要
    private var headerSummary: some View {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_Hant")
        return VStack(alignment: .leading, spacing: 8) {
            Text(f.string(from: Date()))
                .font(.system(size: 28, weight: .bold))
            HStack(spacing: 14) {
                Label("\(fixedItems.count) 個行程", systemImage: "calendar")
                Label(freeMinutes >= 60 ? String(format: "空檔 %.1f 小時", Double(freeMinutes) / 60) : "空檔 \(freeMinutes) 分鐘", systemImage: "hourglass")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - 今日時間軸（行程與空檔交錯）
    private var timelineSection: some View {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return VStack(alignment: .leading, spacing: 10) {
            Text("今日時間軸")
                .font(.headline)
            if fixedItems.isEmpty && gaps.isEmpty {
                Text("今天沒有行程，整天都是空檔")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(12)
            } else {
                ForEach(timelineEntries.indices, id: \.self) { i in
                    switch timelineEntries[i] {
                    case .busy(let item):
                        HStack(spacing: 12) {
                            Text("\(item.startAt.map { f.string(from: $0) } ?? "--")–\(item.endAt.map { f.string(from: $0) } ?? "--")")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 96, alignment: .leading)
                            Text(item.title)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    case .free(let slot):
                        HStack(spacing: 12) {
                            Text("\(f.string(from: slot.start))–\(f.string(from: slot.end))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.green)
                                .frame(width: 96, alignment: .leading)
                            Text("空檔 \(slot.durationMin) 分鐘")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle.dashed")
                                .foregroundColor(.green)
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundColor(Color.green.opacity(0.4))
                        )
                    }
                }
            }
        }
    }

    private enum TimelineEntry {
        case busy(TimeItem)
        case free(GenerationTimeSlot)
        var start: Date {
            switch self {
            case .busy(let i): return i.startAt ?? .distantPast
            case .free(let s): return s.start
            }
        }
    }

    private var timelineEntries: [TimelineEntry] {
        let busy = fixedItems.map { TimelineEntry.busy($0) }
        let free = gaps.map { TimelineEntry.free($0) }
        return (busy + free).sorted { $0.start < $1.start }
    }

    // MARK: - 待安排（建議池＋未排任務）
    @ViewBuilder
    private var pendingSection: some View {
        if !suggestions.isEmpty || !floatingTasks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("待安排")
                    .font(.headline)
                ForEach(suggestions + floatingTasks, id: \.id) { item in
                    pendingRow(item)
                }
            }
        }
    }

    private func pendingRow(_ item: TimeItem) -> some View {
        let id = item.id ?? ""
        let isSelected = selectedIds.contains(id)
        return Button(action: {
            if isSelected { selectedIds.remove(id) } else { selectedIds.insert(id) }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : Color(UIColor.systemGray3))
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                Text("約 \(item.resolvedDurationMin) 分")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.06) : Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 快速新增（臨時待辦，套用時直接成為今天的 event）
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("臨時加一件事")
                .font(.headline)
            HStack(spacing: 10) {
                TextField("例：回覆郵件、去健身房", text: $quickAddTitle)
                    .padding(10)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                Picker("", selection: $quickAddDuration) {
                    Text("30分").tag(30)
                    Text("60分").tag(60)
                    Text("90分").tag(90)
                }
                .pickerStyle(.menu)
                Button(action: addQuickItem) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(quickAddTitle.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                }
                .disabled(quickAddTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ForEach(quickItems, id: \.id) { q in
                let isSelected = selectedQuickIds.contains(q.id)
                Button(action: {
                    if isSelected { selectedQuickIds.remove(q.id) } else { selectedQuickIds.insert(q.id) }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? .blue : Color(UIColor.systemGray3))
                        Text(q.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("約 \(q.durationMin) 分")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: { removeQuickItem(q.id) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(UIColor.systemGray3))
                        }
                    }
                    .padding(12)
                    .background(isSelected ? Color.blue.opacity(0.06) : Color(.systemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func addQuickItem() {
        let title = quickAddTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let id = UUID().uuidString
        quickItems.append((id: id, title: title, durationMin: quickAddDuration))
        selectedQuickIds.insert(id)
        quickAddTitle = ""
    }

    private func removeQuickItem(_ id: String) {
        quickItems.removeAll { $0.id == id }
        selectedQuickIds.remove(id)
    }

    // MARK: - 底部
    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button(action: runSchedule) {
                HStack {
                    if isScheduling { ProgressView().tint(.white) }
                    Text(selectedCount == 0 ? "選擇要排進今天的事" : "AI 排進今天空檔（\(selectedCount)）")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedCount == 0 || freeMinutes == 0 ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(selectedCount == 0 || isScheduling || freeMinutes == 0)
            if freeMinutes == 0 {
                Text("今天已沒有可用空檔")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
        .overlay(Rectangle().fill(Color(UIColor.systemGray5)).frame(height: 0.5), alignment: .top)
    }

    // MARK: - 載入今日 context
    private func load() async {
        isLoading = true
        do {
            let cal = Calendar.current
            let dayStart = cal.startOfDay(for: Date())
            let dayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: dayStart) ?? Date()
            async let fixedAsync = TimeItemService.shared.fetchFixedItems(rangeStart: dayStart, rangeEnd: dayEnd)
            async let sAsync = TimeItemService.shared.fetchSuggestions()
            async let tAsync = TimeItemService.shared.fetchFloatingTasks()
            let (fixed, s, t) = try await (fixedAsync, sAsync, tAsync)
            let window = scheduleWindow
            let computedGaps = Self.computeGaps(rangeStart: window.start, rangeEnd: window.end, fixedItems: fixed)
            await MainActor.run {
                fixedItems = fixed.sorted { ($0.startAt ?? .distantPast) < ($1.startAt ?? .distantPast) }
                gaps = computedGaps
                suggestions = s
                floatingTasks = t
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 空檔計算（與 GenerationSchedulerService 邏輯一致，最小 15 分鐘）
    private static func computeGaps(rangeStart: Date, rangeEnd: Date, fixedItems: [TimeItem]) -> [GenerationTimeSlot] {
        var blocked: [(Date, Date)] = fixedItems.compactMap { item in
            guard let s = item.startAt, let e = item.endAt else { return nil }
            return (s, e)
        }
        blocked.sort { $0.0 < $1.0 }
        var result: [GenerationTimeSlot] = []
        var cursor = rangeStart
        for (s, e) in blocked {
            if cursor < s {
                let slot = GenerationTimeSlot(start: cursor, end: min(s, rangeEnd))
                if slot.durationMin >= 15 { result.append(slot) }
            }
            if e > cursor { cursor = e }
            if cursor >= rangeEnd { break }
        }
        if cursor < rangeEnd {
            let slot = GenerationTimeSlot(start: cursor, end: rangeEnd)
            if slot.durationMin >= 15 { result.append(slot) }
        }
        return result
    }

    // MARK: - 排程 → 預覽
    private func runSchedule() {
        let pendingSelected = (suggestions + floatingTasks).filter { item in
            guard let id = item.id else { return false }
            return selectedIds.contains(id)
        }
        let quickSelected = quickItems.filter { selectedQuickIds.contains($0.id) }
        guard !pendingSelected.isEmpty || !quickSelected.isEmpty else { return }
        isScheduling = true
        Task {
            do {
                let window = scheduleWindow
                let cal = Calendar.current
                let dayStart = cal.startOfDay(for: Date())
                let dayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: dayStart) ?? Date()
                let existing = try await TimeItemService.shared.fetchFixedItems(rangeStart: dayStart, rangeEnd: dayEnd)

                var candidates: [TimeItemCandidate] = pendingSelected.map { item in
                    TimeItemCandidate(
                        id: item.id ?? UUID().uuidString,
                        title: item.title,
                        notes: item.notes,
                        durationMin: item.resolvedDurationMin,
                        type: .task,
                        sourceItemId: item.id  // 修改內容：記錄來源，寫入時帶 linkedTaskId
                    )
                }
                candidates += quickSelected.map { q in
                    TimeItemCandidate(id: q.id, title: q.title, durationMin: q.durationMin, type: .task)
                }

                let scheduled = GenerationSchedulerService.shared.schedule(
                    untimedCandidates: candidates,
                    rangeStart: window.start,
                    rangeEnd: window.end,
                    existingItems: existing
                )
                var riskFlags: [String] = []
                let unplaced = candidates.count - scheduled.count
                if unplaced > 0 {
                    riskFlags.append("今天空檔不足，有 \(unplaced) 項未能排入，可改用「待安排」排進 7 天空檔")
                }
                let conflicts = ConflictDetector.shared.detect(candidates: scheduled, existingItems: existing)
                // 修改內容：未排入者以無時間候選一併進預覽（顯示於「待安排」），不靜默消失
                let scheduledIds = Set(scheduled.map(\.id))
                let previewCandidates = scheduled + candidates.filter { !scheduledIds.contains($0.id) }

                await MainActor.run {
                    isScheduling = false
                    guard !scheduled.isEmpty else {
                        errorMessage = "今天找不到足夠空檔"
                        return
                    }
                    previewResult = GenerationResult(
                        resultType: scheduled.count == candidates.count ? .taskOnly : .partialSuccess,
                        plan: PlanResult(days: [], assumptions: [], riskFlags: riskFlags),
                        candidates: previewCandidates,
                        conflicts: conflicts,
                        riskFlags: riskFlags,
                        requestId: UUID().uuidString,  // 修改內容：每次排程一個穩定 requestId，套用重試去重
                        themeKey: "today_workspace"
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

    // MARK: - 套用後：只把「實際寫入成功」的來源標記為已安排（非完成）、清掉已用的臨時項、刷新今日
    // 修改內容：預覽與套用一致性 — 不再對 selectedIds 全部標 done；未排入 / 失敗者保留在待安排
    private func markConsumedAndReload(_ outcome: ApplyOutcome) {
        let appliedSource = outcome.appliedSourceItemIds
        let appliedCandidateIds = Set(outcome.appliedCandidateIds)
        let consumed = (suggestions + floatingTasks).filter { item in
            guard let id = item.id else { return false }
            return appliedSource.contains(id)
        }
        let usedQuickIds = selectedQuickIds.filter { appliedCandidateIds.contains($0) }
        Task {
            var updated: [TimeItem] = []
            for var item in consumed {
                item.status = .scheduled   // 已排入日曆 ≠ 已完成
                item.updatedAt = Date()
                updated.append(item)
            }
            if !updated.isEmpty {
                do {
                    try await TimeItemService.shared.batchUpdate(updated)
                } catch {
                    await MainActor.run { errorMessage = "已加入日曆，但來源狀態更新失敗：\(error.localizedDescription)" }
                }
            }
            await MainActor.run {
                selectedIds.subtract(appliedSource)
                quickItems.removeAll { usedQuickIds.contains($0.id) }
                selectedQuickIds.subtract(usedQuickIds)
            }
            await load()
        }
    }
}

#Preview {
    TodayWorkspaceView()
        .environmentObject(MockFirebaseUserManager.shared)
}
