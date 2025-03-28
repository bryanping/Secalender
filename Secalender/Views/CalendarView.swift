//
//  CalendarView.swift
//  Secalender
//
//  Created by linping on 2024/6/24.
//
import SwiftUI
import Firebase
import FirebaseFirestore

struct CalendarView: View {
    @State private var currentMonth: Date = Date()
    @State private var events: [Event] = []
    @State private var currentUserOpenid: String = "current_user_openid"
    @State private var scrollToDate: Date?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M.d（E）"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 月份切换
                monthSelector

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            let grouped = groupedEventsWithEmptyDays()
                            ForEach(0..<grouped.count, id: \.self) { index in
                                let (date, dayEvents) = grouped[index]
                                DaySectionView(date: date, events: dayEvents, currentUserOpenid: currentUserOpenid, dateFormatter: dateFormatter, timeFormatter: timeFormatter)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onAppear {
                        fetchEvents()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if let today = scrollToDate {
                                withAnimation {
                                    proxy.scrollTo(today, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var monthSelector: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthFormatter.string(from: currentMonth))
                .font(.headline)
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func groupedEventsWithEmptyDays() -> [(Date, [Event])] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let startOfMonth = calendar.date(from: components)!

        var result: [(Date, [Event])] = []

        let monthEvents = events.filter {
            calendar.isDate($0.date, equalTo: currentMonth, toGranularity: .month)
        }

        let eventDict = Dictionary(grouping: monthEvents, by: { calendar.startOfDay(for: $0.date) })

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let grouped = eventDict[calendar.startOfDay(for: date)] ?? []
                result.append((date, grouped))
            }
        }

        return result
    }

    private func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)!
        fetchEvents()
    }

    private func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)!
        fetchEvents()
    }

    private func fetchEvents() {
        EventManager.shared.fetchEvents { result in
            switch result {
            case .success(let fetched):
                self.events = fetched
                self.scrollToDate = Calendar.current.startOfDay(for: Date())
            case .failure(let error):
                print("读取失败: \(error.localizedDescription)")
            }
        }
    }
}

private let monthFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy · MM"
    return f
}()

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
    }
}
