//
//  EventTroubleshootView.swift
//  Secalender
//
//  修改内容：Step12 — 行程來源診斷：定位每筆行程實際存放位置，並提供刪除來源／永久隱藏
//

import SwiftUI

struct EventTroubleshootView: View {
    @EnvironmentObject var userManager: FirebaseUserManager

    @State private var rows: [Row] = []
    @State private var searchText = ""
    @State private var isWorking = false
    @State private var message: String?
    @State private var showMessage = false

    private var userId: String { userManager.userOpenId }

    struct Row: Identifiable {
        let event: Event
        let sourceLabel: String
        let sourcePath: String?
        let canDeleteSource: Bool
        var id: String { "\(event.id ?? 0)|\(event.date)|\(event.title)" }
    }

    private var filteredRows: [Row] {
        guard !searchText.isEmpty else { return rows }
        return rows.filter {
            $0.event.title.localizedCaseInsensitiveContains(searchText) ||
            $0.event.date.contains(searchText) ||
            $0.sourceLabel.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            Section {
                Text("找不出來源的行程通常來自社群、好友分享或舊版資料。刪除來源會移除雲端文件；永久隱藏只在本機隱藏，不影響他人。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(filteredRows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(row.event.title.isEmpty ? "未命名事件" : row.event.title)
                            .font(.body)
                        Spacer()
                        Text(row.event.date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox")
                            .font(.caption2)
                        Text(row.sourceLabel)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    if let path = row.sourcePath {
                        Text(path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(2)
                    }

                    HStack(spacing: 12) {
                        if row.canDeleteSource {
                            Button("刪除來源") { Task { await deleteSource(row) } }
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        Button("永久隱藏") { hide(row) }
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "搜尋行程或來源")
        .navigationTitle("行程來源診斷")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
        .alert("完成", isPresented: $showMessage) {
            Button("好") { }
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - 資料

    @MainActor
    private func load() {
        let events = DeletedEventRegistry.shared.filterDeleted(
            EventCacheManager.shared.loadEvents(for: userId).filter { $0.deleted != 1 },
            for: userId
        )

        rows = events
            .sorted { ($0.date, $0.startTime) < ($1.date, $1.startTime) }
            .map { event in
                if let itemId = event.timeItemId {
                    return Row(event: event,
                               sourceLabel: "時間項（time_items）",
                               sourcePath: "time_items/\(itemId)",
                               canDeleteSource: true)
                }
                if let id = event.id, let path = EventDocumentIndex.shared.path(for: id) {
                    return Row(event: event,
                               sourceLabel: path.contains("groupEvents") ? "社群行程" : "個人行程（雲端）",
                               sourcePath: path,
                               canDeleteSource: true)
                }
                if let groupId = event.groupId {
                    return Row(event: event,
                               sourceLabel: "社群行程（未建立索引）",
                               sourcePath: "groups/\(groupId)/groupEvents/…",
                               canDeleteSource: true)
                }
                if event.creatorOpenid != userId && !event.creatorOpenid.isEmpty {
                    return Row(event: event,
                               sourceLabel: "他人分享／好友公開行程",
                               sourcePath: "users/\(event.creatorOpenid)/events/…",
                               canDeleteSource: false)
                }
                if event.isAppleImported {
                    return Row(event: event,
                               sourceLabel: "Apple 日曆同步（僅本機）",
                               sourcePath: event.appleCalendarTitle,
                               canDeleteSource: true)
                }
                return Row(event: event,
                           sourceLabel: "僅本機快取",
                           sourcePath: nil,
                           canDeleteSource: true)
            }
    }

    @MainActor
    private func deleteSource(_ row: Row) async {
        guard let eventId = row.event.id else { return }
        isWorking = true
        do {
            try await EventManager.shared.deleteEvent(eventId: eventId)
            message = "已送出刪除：\(row.event.title)"
        } catch {
            DeletedEventRegistry.shared.mark(eventId: eventId, path: row.sourcePath, timeItemId: row.event.timeItemId, for: userId)
            message = "刪除未送達伺服器，已標記為待重試並隱藏。"
        }
        load()
        isWorking = false
        showMessage = true
        NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
    }

    @MainActor
    private func hide(_ row: Row) {
        guard let eventId = row.event.id else { return }
        DeletedEventRegistry.shared.mark(
            eventId: eventId,
            path: nil,                 // 不再嘗試刪除來源，只在本機隱藏
            timeItemId: nil,
            for: userId,
            hideOnly: true
        )
        EventCacheManager.shared.removeEventFromCache(eventId: eventId, for: userId)
        load()
        message = "已永久隱藏：\(row.event.title)"
        showMessage = true
        NotificationCenter.default.post(name: NSNotification.Name("EventSaved"), object: nil)
    }
}
