//
//  DeepLinkCalendarImportView.swift
//  Secalender
//
//  修改内容：ICS 匯入 — 網頁「加入 App 行事曆」深鏈（secalender://addcalendar?url=）：
//  下載並解析公開 ICS → 列出即將到來的活動（可勾選）→ 選擇加入 time_items(type=event)。
//  支援：DTSTART[;TZID=..]:yyyyMMdd'T'HHmmss[Z]、全天 VALUE=DATE、行摺疊、基本跳脫字元。
//

import SwiftUI

struct DeepLinkCalendarImportView: View {
    let icsURL: URL
    let calendarTitle: String?
    let onClose: () -> Void
    @EnvironmentObject var userManager: FirebaseUserManager

    struct ICSEvent: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let location: String?
        let isAllDay: Bool
    }

    @State private var events: [ICSEvent] = []
    @State private var selectedIds: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var savedCount: Int? = nil
    @State private var errorMessage: String? = nil

    private var timeFormatter: DateFormatter {
        let f = DateFormatter.stable("MM/dd HH:mm")
        return f
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("讀取日曆中…")
                    Spacer()
                } else if let msg = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("關閉", action: onClose)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                    Spacer()
                } else if let count = savedCount {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.green)
                        Text("已加入 \(count) 個活動到你的行事曆")
                            .font(.headline)
                        Button("完成", action: onClose)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                    Spacer()
                } else {
                    // 來源說明
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(icsURL.host ?? icsURL.absoluteString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(events) { ev in
                                eventRow(ev)
                            }
                        }
                        .padding()
                    }

                    // 底部
                    VStack(spacing: 8) {
                        Button(action: saveSelected) {
                            HStack {
                                if isSaving { ProgressView().tint(.white) }
                                Text(selectedIds.isEmpty ? "勾選要加入的活動" : "加入行事曆（\(selectedIds.count)）")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedIds.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(selectedIds.isEmpty || isSaving)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemBackground))
                    .overlay(Rectangle().fill(Color(UIColor.systemGray5)).frame(height: 0.5), alignment: .top)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(calendarTitle ?? "匯入日曆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消", action: onClose)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !events.isEmpty && savedCount == nil && errorMessage == nil {
                        Button(selectedIds.count == events.count ? "取消全選" : "全選") {
                            selectedIds = selectedIds.count == events.count ? [] : Set(events.map(\.id))
                        }
                        .font(.subheadline)
                    }
                }
            }
            .task { await load() }
        }
    }

    private func eventRow(_ ev: ICSEvent) -> some View {
        let isSelected = selectedIds.contains(ev.id)
        return Button(action: {
            if isSelected { selectedIds.remove(ev.id) } else { selectedIds.insert(ev.id) }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : Color(UIColor.systemGray3))
                VStack(alignment: .leading, spacing: 4) {
                    Text(ev.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(ev.isAllDay
                             ? DateFormatter.localizedString(from: ev.start, dateStyle: .medium, timeStyle: .none) + "（全天）"
                             : timeFormatter.string(from: ev.start))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let loc = ev.location, !loc.isEmpty {
                            Text(loc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
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
    }

    // MARK: - 下載＋解析
    private func load() async {
        do {
            var request = URLRequest(url: icsURL)
            request.timeoutInterval = 20
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let text = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "ICS", code: 0, userInfo: [NSLocalizedDescriptionKey: "無法讀取日曆內容"])
            }
            let parsed = Self.parseICS(text)
            let now = Calendar.current.startOfDay(for: Date())
            let horizon = Calendar.current.date(byAdding: .day, value: 365, to: now) ?? now
            let upcoming = parsed
                .filter { $0.start >= now && $0.start <= horizon }
                .sorted { $0.start < $1.start }
            await MainActor.run {
                events = Array(upcoming.prefix(100))
                selectedIds = Set(events.prefix(30).map(\.id))  // 預設勾選近期 30 筆
                isLoading = false
                if events.isEmpty {
                    errorMessage = "這份日曆沒有未來一年內的活動"
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "日曆讀取失敗：\(error.localizedDescription)"
            }
        }
    }

    /// 最小 ICS 解析：unfold → VEVENT 掃描（SUMMARY/DTSTART/DTEND/LOCATION/UID）
    static func parseICS(_ raw: String) -> [ICSEvent] {
        // 行摺疊還原（下一行以空白/Tab 開頭表示接續）
        let unfolded = raw
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
        let lines = unfolded.split(whereSeparator: \.isNewline).map(String.init)

        let utcFormatter = DateFormatter.stable("yyyyMMdd'T'HHmmss'Z'")
        utcFormatter.timeZone = TimeZone(identifier: "UTC")
        let localFormatter = DateFormatter.stable("yyyyMMdd'T'HHmmss")
        let dayFormatter = DateFormatter.stable("yyyyMMdd")

        func unescape(_ s: String) -> String {
            s.replacingOccurrences(of: "\\n", with: " ")
                .replacingOccurrences(of: "\\,", with: ",")
                .replacingOccurrences(of: "\\;", with: ";")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        func parseDate(_ value: String, params: String) -> (Date, Bool)? {
            if params.contains("VALUE=DATE"), let d = dayFormatter.date(from: value) {
                return (d, true)
            }
            if value.hasSuffix("Z"), let d = utcFormatter.date(from: value) {
                return (d, false)
            }
            if let tzId = params.split(separator: ";").first(where: { $0.hasPrefix("TZID=") })?.dropFirst(5),
               let tz = TimeZone(identifier: String(tzId)) {
                localFormatter.timeZone = tz
                if let d = localFormatter.date(from: value) { return (d, false) }
            }
            localFormatter.timeZone = .current
            if let d = localFormatter.date(from: value) { return (d, false) }
            if let d = dayFormatter.date(from: value) { return (d, true) }
            return nil
        }

        var results: [ICSEvent] = []
        var inEvent = false
        var summary = "", location: String? = nil, uid: String? = nil
        var start: (Date, Bool)? = nil, end: (Date, Bool)? = nil

        for line in lines {
            if line == "BEGIN:VEVENT" {
                inEvent = true
                summary = ""; location = nil; uid = nil; start = nil; end = nil
                continue
            }
            if line == "END:VEVENT" {
                inEvent = false
                if let s = start, !summary.isEmpty {
                    let isAllDay = s.1
                    let endDate = end?.0 ?? (isAllDay ? s.0.addingTimeInterval(86399) : s.0.addingTimeInterval(3600))
                    results.append(ICSEvent(
                        id: uid ?? "\(summary)-\(s.0.timeIntervalSince1970)",
                        title: summary,
                        start: s.0,
                        end: max(endDate, s.0),
                        location: location,
                        isAllDay: isAllDay
                    ))
                }
                continue
            }
            guard inEvent, let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon])
            let value = String(line[line.index(after: colon)...])
            let name = key.split(separator: ";").first.map(String.init) ?? key
            switch name {
            case "SUMMARY": summary = unescape(value)
            case "LOCATION": location = unescape(value)
            case "UID": uid = value
            case "DTSTART": start = parseDate(value, params: key)
            case "DTEND": end = parseDate(value, params: key)
            default: break
            }
        }
        return results
    }

    // MARK: - 加入所選 → time_items
    private func saveSelected() {
        let picked = events.filter { selectedIds.contains($0.id) }
        guard !picked.isEmpty else { return }
        isSaving = true
        Task {
            var ok = 0
            for ev in picked {
                let item = TimeItem(
                    type: .event,
                    title: ev.title,
                    notes: ev.location.map { "地點：\($0)" },
                    startAt: ev.start,
                    endAt: ev.end,
                    hasStartAt: true,
                    themeKey: "ics_import",
                    source: .imported,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                if (try? await TimeItemService.shared.upsert(item)) != nil { ok += 1 }
            }
            await MainActor.run {
                isSaving = false
                savedCount = ok
            }
        }
    }
}
