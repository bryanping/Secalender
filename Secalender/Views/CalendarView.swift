////
//  CalendarView.swift
//  Secalender
//

import SwiftUI
import Foundation
import Firebase


struct CalendarView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var currentMonth: Date = Date()
    @State private var events: [Event] = []
    @State private var scrollToDate: Date?
    @State private var showCreateEvent = false
    @State private var selectedDateForNewEvent: Date?
    @State private var selectedEvent: Event?
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
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
                                        allowNavigation: true,
                                        onEventUpdated: {
                                            Task { @MainActor in
                                                await loadEvents()
                                            }
                                        }
                                    )
                                    .onTapGesture(count: 2) {
                                        selectedDateForNewEvent = date
                                        showCreateEvent = true
                                    }
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .refreshable {
                        await loadEvents(proxy: proxy)
                    }
                    .onAppear {
                        Task { @MainActor in
                            await loadEvents(proxy: proxy)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EmptyView()
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
                            Task { @MainActor in
                                await loadEvents()
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - 数据加载方法
    private func loadEvents(proxy: ScrollViewProxy? = nil) async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let fetched = try await EventManager.shared.fetchEvents()
            
            // 过滤掉已删除的事件
            let activeEvents = fetched.filter { $0.deleted != 1 }
            
            // 按ID去重，保留最新的事件
            var uniqueEventsDict: [Int: Event] = [:]
            for event in activeEvents {
                if let eventId = event.id {
                    uniqueEventsDict[eventId] = event
                }
            }
            let uniqueEvents = Array(uniqueEventsDict.values)

            await MainActor.run {
                self.events = uniqueEvents
                self.scrollToDate = Calendar.current.startOfDay(for: Date())
                self.isLoading = false
            }

            // 数据加载完成

        } catch {
            print("❌ 加载事件失败: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private var headerView: some View {
        HStack {
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
            Button {
                selectedDateForNewEvent = Date()
                showCreateEvent = true
            } label: {
                Image(systemName: "plus.circle")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
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
            if let dateObj = event.dateObj {
                let targetDate = calendar.startOfDay(for: dateObj)
                if eventDict[targetDate] == nil {
                    eventDict[targetDate] = []
                }
                eventDict[targetDate]?.append(event)
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
