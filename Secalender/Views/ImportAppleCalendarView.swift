//
//  ImportAppleCalendarView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//  修改内容：Apple 同步 Step5 — 改為「來源日曆訂閱式同步」：自動同步置頂，
//  開啟來源即同步該日曆的全部行程（含過去），不再逐筆挑選。
//

import SwiftUI
import EventKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct ImportAppleCalendarView: View {
    /// 修改内容：Step15 — 嵌入「日曆管理」時不自帶導覽容器
    var embedded: Bool = false

    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @StateObject private var calendarManager = AppleCalendarManager.shared

    @State private var calendars: [EKCalendar] = []
    @State private var syncedIds: Set<String> = []
    @State private var importedCountByCalendar: [String: Int] = [:]
    @State private var totalImported = 0
    @State private var isLoading = true
    @State private var syncingCalendarId: String?
    @State private var isSyncingAll = false
    @State private var permissionDenied = false
    @State private var autoSyncEnabled = false
    @State private var pendingUnsubscribe: EKCalendarBox?
    @State private var resultMessage: String?
    @State private var showResult = false

    private var userId: String { userManager.userOpenId }

    /// 用於 alert(item:) 的包裝
    struct EKCalendarBox: Identifiable {
        let id: String
        let title: String
        let importedCount: Int
    }

    /// 依帳號來源（iCloud／訂閱⋯）再依名稱排序
    private var sortedCalendars: [EKCalendar] {
        calendars.sorted {
            let s0 = $0.source?.title ?? ""
            let s1 = $1.source?.title ?? ""
            return s0 == s1 ? $0.title < $1.title : s0 < s1
        }
    }

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
        Group {
            Group {
                if isLoading {
                    ProgressView("讀取日曆…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if permissionDenied {
                    permissionView
                } else {
                    contentList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("日曆同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("完成") { dismiss() }
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .alert(item: $pendingUnsubscribe) { box in
                Alert(
                    title: Text("停止同步「\(box.title)」"),
                    message: Text("已同步的 \(box.importedCount) 個行程要一併移除嗎？Apple 日曆原始資料不受影響。"),
                    primaryButton: .destructive(Text("移除行程")) {
                        unsubscribe(box.id, removeEvents: true)
                    },
                    secondaryButton: .default(Text("保留行程")) {
                        unsubscribe(box.id, removeEvents: false)
                    }
                )
            }
            .alert("同步完成", isPresented: $showResult) {
                Button("好") { }
            } message: {
                Text(resultMessage ?? "")
            }
        }
    }

    // MARK: - 內容

    private var contentList: some View {
        List {
            // 1. 自動同步（主要功能，置頂）
            Section {
                Toggle(isOn: $autoSyncEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自動同步")
                            .font(.headline)
                        Text("每次開啟 App 自動同步已選來源的新舊行程")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.blue)
                .onChange(of: autoSyncEnabled) { _, newValue in
                    Task {
                        try? await UserPreferencesManager.shared.setAutoImportAppleCalendar(newValue, for: userId)
                        if newValue { await syncAll() }
                    }
                }

                Button {
                    Task { await syncAll() }
                } label: {
                    HStack {
                        if isSyncingAll {
                            ProgressView().padding(.trailing, 4)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isSyncingAll ? "同步中…" : "立即同步全部來源")
                        Spacer()
                    }
                }
                .disabled(isSyncingAll || syncedIds.isEmpty)
            } header: {
                Text("同步設定")
            } footer: {
                Text(syncedIds.isEmpty
                     ? "尚未選擇同步來源，請於下方開啟要同步的日曆。"
                     : "已同步 \(totalImported) 個行程，來自 \(syncedIds.count) 個來源日曆。整份日曆完整同步，不限時間區段。")
            }

            // 2. 來源日曆開關
            Section {
                if calendars.isEmpty {
                    Text("沒有可用的 Apple 日曆")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sortedCalendars, id: \.calendarIdentifier) { calendar in
                        calendarToggleRow(calendar)
                    }
                }
            } header: {
                Text("同步來源")
            } footer: {
                Text("開啟後會立即同步該日曆的全部行程（含過去與未來）；每月／每年重複的行程只儲存一筆，由 App 自動展開，不會佔用多筆資料。")
            }

            // 3. 管理
            Section {
                NavigationLink {
                    AppleImportManageView()
                        .environmentObject(userManager)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "tray.full")
                            .foregroundColor(.blue)
                            .frame(width: 22)
                        Text("管理已同步行程")
                        Spacer()
                        Text("\(totalImported)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func calendarToggleRow(_ calendar: EKCalendar) -> some View {
        let id = calendar.calendarIdentifier
        let count = importedCountByCalendar[id] ?? 0
        return Toggle(isOn: Binding(
            get: { syncedIds.contains(id) },
            set: { newValue in setSubscription(calendar, on: newValue) }
        )) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color(of: calendar))
                    .frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                    if syncingCalendarId == id {
                        Text("同步中…")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    } else {
                        Text(count > 0
                             ? "\(calendar.source?.title ?? "") · 已同步 \(count) 個行程"
                             : (calendar.source?.title ?? ""))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .tint(.blue)
        .disabled(syncingCalendarId != nil)
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("需要日曆權限")
                .font(.headline)
            Text("請前往「設定 → 隱私權與安全性 → 行事曆」開啟權限後再試。")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("前往設定") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 動作

    @MainActor
    private func load() async {
        isLoading = true
        permissionDenied = false

        var granted = false
        await withCheckedContinuation { continuation in
            calendarManager.requestAccessIfNeeded { result in
                granted = result
                continuation.resume()
            }
        }
        guard granted else {
            permissionDenied = true
            isLoading = false
            return
        }

        AppleCalendarImportManager.shared.cleanupDuplicates(for: userId, force: true)

        calendars = calendarManager.getAllEventCalendars()
        let prefs = UserPreferencesManager.shared
        autoSyncEnabled = prefs.getAutoImportAppleCalendar(for: userId)
        syncedIds = prefs.getSyncedCalendarIds(for: userId)

        refreshCounts()
        isLoading = false
    }

    private func refreshCounts() {
        let records = AppleCalendarImportManager.shared.records(for: userId)
        totalImported = records.count
        importedCountByCalendar = records.reduce(into: [:]) { dict, record in
            dict[record.calendarId, default: 0] += 1
        }
    }

    private func setSubscription(_ calendar: EKCalendar, on: Bool) {
        let id = calendar.calendarIdentifier
        if on {
            var ids = syncedIds
            ids.insert(id)
            syncedIds = ids
            UserPreferencesManager.shared.setSyncedCalendarIds(ids, for: userId)
            Task { await syncOne(id) }
        } else {
            pendingUnsubscribe = EKCalendarBox(
                id: id,
                title: calendar.title,
                importedCount: importedCountByCalendar[id] ?? 0
            )
        }
    }

    @MainActor
    private func syncOne(_ calendarId: String) async {
        syncingCalendarId = calendarId
        let imported = await AppleCalendarImportManager.shared.syncCalendars(ids: [calendarId], for: userId)
        syncingCalendarId = nil
        refreshCounts()
        resultMessage = imported > 0 ? "已同步 \(imported) 個行程（含過去行程）。" : "此來源沒有新的行程需要同步。"
        showResult = true
    }

    @MainActor
    private func syncAll() async {
        guard !syncedIds.isEmpty else { return }
        isSyncingAll = true
        let imported = await AppleCalendarImportManager.shared.syncAllSubscribedCalendars(for: userId)
        isSyncingAll = false
        refreshCounts()
        resultMessage = imported > 0 ? "已同步 \(imported) 個新行程。" : "所有來源皆為最新狀態。"
        showResult = true
    }

    @MainActor
    private func unsubscribe(_ calendarId: String, removeEvents: Bool) {
        AppleCalendarImportManager.shared.unsubscribeCalendar(
            calendarId,
            removeImportedEvents: removeEvents,
            for: userId
        )
        syncedIds = UserPreferencesManager.shared.getSyncedCalendarIds(for: userId)
        refreshCounts()
    }

    private func color(of calendar: EKCalendar) -> Color {
        guard let cg = calendar.cgColor else { return .blue }
        return Color(cgColor: cg)
    }
}
