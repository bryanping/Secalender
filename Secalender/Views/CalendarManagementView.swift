//
//  CalendarManagementView.swift
//  Secalender
//
//  修改内容：Step15 — 日曆管理總入口（同步日曆／已同步行程／刪除歷史／來源診斷）
//

import SwiftUI

struct CalendarManagementView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    /// 由 sheet 開啟時顯示「完成」按鈕；從設定推入時不顯示
    var showsDoneButton: Bool = false
    @Environment(\.dismiss) private var dismiss

    @State private var syncedCount = 0
    @State private var importedCount = 0
    @State private var deletedCount = 0

    private var userId: String { userManager.userOpenId }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ImportAppleCalendarView(embedded: true)
                        .environmentObject(userManager)
                } label: {
                    row(icon: "calendar.badge.plus", color: .blue,
                        title: "同步日曆",
                        subtitle: syncedCount > 0 ? "已訂閱 \(syncedCount) 個來源日曆" : "選擇要同步的 Apple 日曆")
                }

                NavigationLink {
                    AppleImportManageView()
                        .environmentObject(userManager)
                } label: {
                    row(icon: "tray.full", color: .indigo,
                        title: "已同步行程",
                        subtitle: "\(importedCount) 個行程")
                }
            } header: {
                Text("同步內容")
            } footer: {
                Text("")
            }

            Section {
                NavigationLink {
                    DeletionHistoryView()
                        .environmentObject(userManager)
                } label: {
                    row(icon: "clock.arrow.circlepath", color: .orange,
                        title: "刪除歷史",
                        subtitle: deletedCount > 0 ? "\(deletedCount) 筆待確認／已刪除" : "沒有紀錄")
                }

                NavigationLink {
                    EventTroubleshootView()
                        .environmentObject(userManager)
                } label: {
                    row(icon: "magnifyingglass", color: .teal,
                        title: "行程來源診斷",
                        subtitle: "查看每筆行程的實際存放位置")
                }
            } header: {
                Text("行程管理")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("日曆管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                }
            }
        }
        // 修改内容：Step18 — 只在進入頁面時統計一次，避免每則 EventSaved 都重讀全部紀錄造成卡頓
        .task { refresh() }
    }

    private func row(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(color))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @MainActor
    private func refresh() {
        guard !userId.isEmpty else { return }
        syncedCount = UserPreferencesManager.shared.getSyncedCalendarIds(for: userId).count
        importedCount = AppleCalendarImportManager.shared.records(for: userId).count
        deletedCount = DeletedEventRegistry.shared.history(for: userId).count
    }
}

// MARK: - 刪除歷史

struct DeletionHistoryView: View {
    @EnvironmentObject var userManager: FirebaseUserManager

    @State private var items: [DeletedEventRegistry.Tombstone] = []
    @State private var confirmClear = false

    private var userId: String { userManager.userOpenId }

    var body: some View {
        Group {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("沒有刪除紀錄")
                        .font(.headline)
                    Text("刪除行程後會在此列出，包含尚未同步到雲端的項目。")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items, id: \.eventId) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title?.isEmpty == false ? item.title! : "未命名行程")
                                    .font(.body)
                                Spacer()
                                Text(item.date ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: statusIcon(item))
                                    .font(.caption2)
                                Text(statusText(item))
                                    .font(.caption)
                                Spacer()
                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                            }
                            .foregroundColor(statusColor(item))
                        }
                        .padding(.vertical, 3)
                        .swipeActions(edge: .trailing) {
                            Button("移除紀錄") { remove(item) }
                                .tint(.gray)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("刪除歷史")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清空") { confirmClear = true }
                    .disabled(items.isEmpty)
            }
        }
        .task { load() }
        .alert("清空刪除歷史？", isPresented: $confirmClear) {
            Button("清空", role: .destructive) { clearAll() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("僅清除紀錄，不會恢復已刪除的行程；尚未同步的刪除會失去重試機會。")
        }
    }

    private func statusIcon(_ item: DeletedEventRegistry.Tombstone) -> String {
        item.hideOnly == true ? "eye.slash" : "arrow.triangle.2.circlepath"
    }

    private func statusText(_ item: DeletedEventRegistry.Tombstone) -> String {
        if item.hideOnly == true { return "已隱藏（來源保留）" }
        if item.timeItemId != nil { return "待同步刪除 · 時間項" }
        return item.path == nil ? "待同步刪除" : "待同步刪除 · 雲端行程"
    }

    private func statusColor(_ item: DeletedEventRegistry.Tombstone) -> Color {
        item.hideOnly == true ? .secondary : .orange
    }

    @MainActor
    private func load() {
        items = DeletedEventRegistry.shared.history(for: userId)
    }

    @MainActor
    private func remove(_ item: DeletedEventRegistry.Tombstone) {
        DeletedEventRegistry.shared.clear(eventId: item.eventId, for: userId)
        load()
    }

    @MainActor
    private func clearAll() {
        DeletedEventRegistry.shared.clearHistory(for: userId)
        load()
    }
}
