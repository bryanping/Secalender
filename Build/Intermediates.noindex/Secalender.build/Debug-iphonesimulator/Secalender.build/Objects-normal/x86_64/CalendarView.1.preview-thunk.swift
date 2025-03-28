import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/linping/Desktop/活動歷/MyFirstProgram/Secalender/Secalender/Views/CalendarView.swift", line: 1)
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
            VStack(spacing: __designTimeInteger("#2263_0", fallback: 0)) {
                // 月份切换
                monthSelector

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: __designTimeInteger("#2263_1", fallback: 16)) {
                            let grouped = groupedEventsWithEmptyDays()
                            ForEach(__designTimeInteger("#2263_2", fallback: 0)..<grouped.count, id: \.self) { index in
                                let (date, dayEvents) = grouped[index]
                                DaySectionView(date: date, events: dayEvents, currentUserOpenid: currentUserOpenid, dateFormatter: dateFormatter, timeFormatter: timeFormatter)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onAppear {
                        fetchEvents()
                        DispatchQueue.main.asyncAfter(deadline: .now() + __designTimeFloat("#2263_3", fallback: 0.3)) {
                            if let today = scrollToDate {
                                withAnimation {
                                    proxy.scrollTo(today, anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(__designTimeBoolean("#2263_4", fallback: true))
        }
    }

    private var monthSelector: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: __designTimeString("#2263_5", fallback: "chevron.left"))
            }
            Spacer()
            Text(monthFormatter.string(from: currentMonth))
                .font(.headline)
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: __designTimeString("#2263_6", fallback: "chevron.right"))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, __designTimeInteger("#2263_7", fallback: 8))
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
            if let date = calendar.date(byAdding: .day, value: day - __designTimeInteger("#2263_8", fallback: 1), to: startOfMonth) {
                let grouped = eventDict[calendar.startOfDay(for: date)] ?? []
                result.append((date, grouped))
            }
        }

        return result
    }

    private func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: __designTimeInteger("#2263_9", fallback: -1), to: currentMonth)!
        fetchEvents()
    }

    private func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: __designTimeInteger("#2263_10", fallback: 1), to: currentMonth)!
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
