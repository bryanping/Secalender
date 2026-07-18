//
//  ReviewView.swift
//  Secalender
//
//  回顧頁：時間軸 + 人物軸 + 關係維護提醒
//  資料來源 Cloud Function getReviewSummary（MetricService.fetchReviewSummary）
//

import SwiftUI

// MARK: - Model

struct ReviewSummary {
    struct TimeAxis { var createdEvents = 0; var completedEvents = 0 }
    struct PeopleAxis {
        var withPeopleEvents = 0
        var attendedEvents = 0
        var uniqueContacts = 0
        var shared = 0
    }
    struct StaleContact: Identifiable {
        let id: String
        let displayName: String
        let days: Int
    }

    var time = TimeAxis()
    var people = PeopleAxis()
    var staleContacts: [StaleContact] = []

    static func parse(_ raw: [String: Any]) -> ReviewSummary {
        var s = ReviewSummary()
        if let t = raw["time"] as? [String: Any] {
            s.time.createdEvents = intOf(t["createdEvents"])
            s.time.completedEvents = intOf(t["completedEvents"])
        }
        if let p = raw["people"] as? [String: Any] {
            s.people.withPeopleEvents = intOf(p["withPeopleEvents"])
            s.people.attendedEvents = intOf(p["attendedEvents"])
            s.people.uniqueContacts = intOf(p["uniqueContacts"])
            s.people.shared = intOf(p["shared"])
        }
        if let r = raw["reminders"] as? [String: Any],
           let list = r["staleContacts"] as? [[String: Any]] {
            s.staleContacts = list.compactMap { item in
                guard let id = item["contactId"] as? String, !id.isEmpty else { return nil }
                return StaleContact(
                    id: id,
                    displayName: (item["displayName"] as? String) ?? id,
                    days: intOf(item["days"])
                )
            }
        }
        return s
    }

    private static func intOf(_ v: Any?) -> Int {
        if let n = v as? Int { return n }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String, let n = Int(s) { return n }
        return 0
    }
}

// MARK: - ViewModel

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published private(set) var summary = ReviewSummary()
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    func load(staleDays: Int = 60) async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        if let raw = await MetricService.fetchReviewSummary(staleDays: staleDays) {
            summary = ReviewSummary.parse(raw)
        } else {
            loadFailed = true
        }
    }
}

// MARK: - View

struct ReviewView: View {
    @StateObject private var viewModel = ReviewViewModel()

    var body: some View {
        List {
            timeSection
            peopleSection
            reminderSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("回顧")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    // 時間軸
    private var timeSection: some View {
        Section("時間軸") {
            statRow(icon: "calendar.badge.plus", title: "建立行程", value: viewModel.summary.time.createdEvents)
            statRow(icon: "checkmark.circle", title: "完成行程", value: viewModel.summary.time.completedEvents)
        }
    }

    // 人物軸
    private var peopleSection: some View {
        Section("人物軸") {
            statRow(icon: "person.2", title: "與人見面的行程", value: viewModel.summary.people.withPeopleEvents)
            statRow(icon: "hand.wave", title: "赴約完成", value: viewModel.summary.people.attendedEvents)
            statRow(icon: "person.crop.circle.badge.checkmark", title: "互動過的人", value: viewModel.summary.people.uniqueContacts)
            statRow(icon: "square.and.arrow.up", title: "分享／邀請", value: viewModel.summary.people.shared)
        }
    }

    // 關係維護提醒
    private var reminderSection: some View {
        Section("久未聯絡") {
            if viewModel.summary.staleContacts.isEmpty {
                Text(viewModel.loadFailed ? "載入失敗，下拉重試" : "沒有久未聯絡的對象")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.summary.staleContacts) { c in
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.orange)
                        Text(c.displayName)
                        Spacer()
                        Text("\(c.days) 天未見")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func statRow(icon: String, title: String, value: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.accentColor)
            Text(title)
            Spacer()
            Text("\(value)")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundColor(.secondary)
        }
    }
}
