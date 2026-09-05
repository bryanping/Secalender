//
//  AppleImportManageView.swift
//  Secalender
//
//  修改内容：Apple 匯入 Step3 — 已導入內容管理（清單／移除／重新同步）
//

import SwiftUI
import EventKit

struct AppleImportManageView: View {
    @EnvironmentObject var userManager: FirebaseUserManager

    @State private var groups: [ImportGroup] = []
    @State private var duplicateGroups: [AppleCalendarImportManager.DuplicateGroup] = []
    @State private var searchText = ""
    @State private var selection = Set<String>()
    @State private var editMode: EditMode = .inactive
    @State private var isWorking = false
    @State private var confirmRemoveAll = false
    @State private var confirmRemoveCalendar: ImportGroup?
    @State private var resultMessage: String?
    @State private var showResult = false

    private var userId: String { userManager.userOpenId }

    struct ImportGroup: Identifiable, Equatable {
        let calendarId: String
        let calendarTitle: String
        let color: Color
        let records: [AppleImportRecord]
        var id: String { calendarId }

        static func == (lhs: ImportGroup, rhs: ImportGroup) -> Bool {
            lhs.calendarId == rhs.calendarId && lhs.records.count == rhs.records.count
        }
    }

    private var totalCount: Int { groups.reduce(0) { $0 + $1.records.count } }

    private var filteredGroups: [ImportGroup] {
        guard !searchText.isEmpty else { return groups }
        return groups.compactMap { group in
            let matched = group.records.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.date.contains(searchText) ||
                group.calendarTitle.localizedCaseInsensitiveContains(searchText)
            }
            return matched.isEmpty ? nil : ImportGroup(
                calendarId: group.calendarId,
                calendarTitle: group.calendarTitle,
                color: group.color,
                records: matched
            )
        }
    }

    var body: some View {
        Group {
            if totalCount == 0 && duplicateGroups.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("已導入內容")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task { await resync() }
                    } label: {
                        Label("重新同步", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                            selection.removeAll()
                        }
                    } label: {
                        Label(editMode == .active ? "完成選取" : "選取行程", systemImage: "checkmark.circle")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmRemoveAll = true
                    } label: {
                        Label("移除全部導入", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(isWorking)
            }
        }
        .environment(\.editMode, $editMode)
        .task { load() }
        .alert("移除全部導入行程？", isPresented: $confirmRemoveAll) {
            Button("移除", role: .destructive) { removeAll() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("將從本 App 移除 \(totalCount) 個導入的行程，Apple 日曆中的原始行程不受影響。")
        }
        .alert(item: $confirmRemoveCalendar) { group in
            Alert(
                title: Text("移除「\(group.calendarTitle)」的導入行程？"),
                message: Text("共 \(group.records.count) 個行程，Apple 日曆原始資料不受影響。"),
                primaryButton: .destructive(Text("移除")) { removeCalendar(group) },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .alert("完成", isPresented: $showResult) {
            Button("好") { }
        } message: {
            Text(resultMessage ?? "")
        }
    }

    // MARK: - 子視圖

    private var listView: some View {
        List(selection: $selection) {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "tray.full")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(totalCount) 個導入行程")
                            .font(.headline)
                        Text("來自 \(groups.count) 個日曆")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if isWorking { ProgressView() }
                }
                .listRowBackground(Color(.secondarySystemGroupedBackground))
            }

            // 修改内容：Apple 同步 Step7 — 重複行程（含更早版本、已上傳雲端的殘留）
            if !duplicateGroups.isEmpty {
                Section {
                    ForEach(duplicateGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(group.title.isEmpty ? "未命名事件" : group.title)
                                    .font(.body)
                                Spacer()
                                Text(group.date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("共 \(group.events.count) 筆 · 保留「\(sourceLabel(group.events.first))」，刪除其餘 \(group.removable.count) 筆")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(role: .destructive) {
                        Task { await removeDuplicates() }
                    } label: {
                        HStack {
                            if isWorking { ProgressView().padding(.trailing, 4) }
                            Text("清除重複行程（\(duplicateRemovableCount) 筆）")
                        }
                    }
                    .disabled(isWorking)
                } header: {
                    Text("重複行程")
                } footer: {
                    Text("每組只保留一筆（優先保留有同步來源者），其餘會一併從雲端與本機刪除。")
                }
            }

            ForEach(filteredGroups) { group in
                Section {
                    ForEach(group.records) { record in
                        AppleImportedRecordRow(record: record, color: group.color)
                            .tag(record.occurrenceKey)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    remove([record.occurrenceKey])
                                } label: {
                                    Label("移除", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Circle().fill(group.color).frame(width: 10, height: 10)
                        Text(group.calendarTitle)
                        Spacer()
                        Button("移除此來源") { confirmRemoveCalendar = group }
                            .font(.caption)
                            .foregroundColor(.red)
                            .textCase(nil)
                    }
                }
            }

            // 修改内容：Step12 — 行程來源診斷入口
            Section {
                NavigationLink {
                    EventTroubleshootView()
                        .environmentObject(userManager)
                } label: {
                    Label("行程來源診斷", systemImage: "magnifyingglass")
                }
            } footer: {
                Text("找出刪不掉的行程實際存放位置，可刪除來源或永久隱藏。")
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "搜尋已導入行程")
        .safeAreaInset(edge: .bottom) {
            if editMode == .active {
                Button(role: .destructive) {
                    remove(selection)
                } label: {
                    Text("移除選取的 \(selection.count) 個行程")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selection.isEmpty ? Color.gray.opacity(0.4) : Color.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selection.isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("尚未導入任何行程")
                .font(.headline)
            Text("回到上一頁選擇來源日曆即可導入。")
                .font(.callout)
                .foregroundColor(.secondary)

            NavigationLink {
                EventTroubleshootView()
                    .environmentObject(userManager)
            } label: {
                Label("行程來源診斷", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 資料

    private var duplicateRemovableCount: Int {
        duplicateGroups.reduce(0) { $0 + $1.removable.count }
    }

    private func sourceLabel(_ event: Event?) -> String {
        event?.importSourceName ?? "App 內行程"
    }

    /// 清除重複行程：每組保留第一筆，其餘連同雲端資料刪除
    @MainActor
    private func removeDuplicates() async {
        isWorking = true
        var deleted = 0
        var failed = 0

        for group in duplicateGroups {
            for event in group.removable {
                guard let eventId = event.id else { continue }
                do {
                    try await EventManager.shared.deleteEvent(eventId: eventId)
                    AppleCalendarImportManager.shared.removeImportRecord(appEventId: eventId, for: userId)
                    deleted += 1
                } catch {
                    print("⚠️ 刪除重複行程失敗: \(error.localizedDescription)")
                    failed += 1
                }
            }
        }

        load()
        isWorking = false
        resultMessage = failed == 0
            ? "已刪除 \(deleted) 筆重複行程。"
            : "已刪除 \(deleted) 筆，\(failed) 筆刪除失敗，請稍後再試。"
        showResult = true
        NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
    }

    @MainActor
    private func load() {
        // 修改内容：Apple 匯入 Step4 — 進頁先清理重複匯入
        AppleCalendarImportManager.shared.cleanupDuplicates(for: userId, force: true)
        duplicateGroups = AppleCalendarImportManager.shared.duplicateEventGroups(for: userId)
        let grouped = AppleCalendarImportManager.shared.recordsGroupedByCalendar(for: userId)
        groups = grouped.map { item in
            let ekCalendar = AppleCalendarManager.shared.calendar(withIdentifier: item.calendarId)
            let color: Color = ekCalendar?.cgColor.map { Color(cgColor: $0) } ?? .blue
            return ImportGroup(
                calendarId: item.calendarId,
                calendarTitle: ekCalendar?.title ?? item.calendarTitle,
                color: color,
                records: item.records
            )
        }
    }

    @MainActor
    private func remove(_ keys: Set<String>) {
        guard !keys.isEmpty else { return }
        AppleCalendarImportManager.shared.removeImported(occurrenceKeys: keys, for: userId)
        selection.subtract(keys)
        load()
    }

    @MainActor
    private func removeCalendar(_ group: ImportGroup) {
        AppleCalendarImportManager.shared.removeImportedCalendar(calendarId: group.calendarId, for: userId)
        load()
    }

    @MainActor
    private func removeAll() {
        AppleCalendarImportManager.shared.removeAllImported(for: userId)
        selection.removeAll()
        editMode = .inactive
        load()
    }

    @MainActor
    private func resync() async {
        isWorking = true
        let result = AppleCalendarImportManager.shared.resyncImported(for: userId)
        load()
        isWorking = false
        resultMessage = "更新 \(result.updated) 個行程，移除 \(result.removed) 個已在 Apple 日曆刪除的行程。"
        showResult = true
    }
}

// MARK: - 已導入行程列

struct AppleImportedRecordRow: View {
    let record: AppleImportRecord
    let color: Color

    private var dateText: String {
        guard let date = DateFormatter.stable("yyyy-MM-dd").date(from: record.date) else { return record.date }
        let formatter = DateFormatter.stable("M月d日 (E)")
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }

    private var timeText: String {
        if record.isAllDay { return "全天" }
        return String(record.startTime.prefix(5))
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title.isEmpty ? "未命名事件" : record.title)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(dateText)
                    Text("·")
                    Text(timeText)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}
