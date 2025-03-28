import func SwiftUI.__designTimeSelection

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

    var body: some View {
        __designTimeSelection(NavigationView {
            __designTimeSelection(VStack {
                // 顶部月份选择
                __designTimeSelection(HStack {
                    __designTimeSelection(Button(action: __designTimeSelection(previousMonth, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[0].arg[0].value")) {
                        __designTimeSelection(Image(systemName: __designTimeString("#2263_0", fallback: "chevron.left")), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[0].arg[1].value.[0]")
                    }, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[0]")
                    __designTimeSelection(Spacer(), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[1]")
                    __designTimeSelection(Text(__designTimeSelection(monthFormatter.string(from: __designTimeSelection(currentMonth, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.modifier[0].arg[0].value")), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[2].arg[0].value"))
                        .font(.headline), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[2]")
                    __designTimeSelection(Spacer(), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[3]")
                    __designTimeSelection(Button(action: __designTimeSelection(nextMonth, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[4].arg[0].value")) {
                        __designTimeSelection(Image(systemName: __designTimeString("#2263_1", fallback: "chevron.right")), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[4].arg[1].value.[0]")
                    }, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0].arg[0].value.[4]")
                }
                .padding(.horizontal)
                .padding(.top), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[0]")

                __designTimeSelection(Divider(), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[1]")

                __designTimeSelection(ScrollViewReader { proxy in
                    __designTimeSelection(ScrollView {
                        __designTimeSelection(LazyVStack(alignment: .leading, spacing: __designTimeInteger("#2263_2", fallback: 16)) {
                            __designTimeSelection(ForEach(__designTimeSelection(groupedEventsWithEmptyDays(), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[0].value"), id: \.0) { (date, dayEvents) in
                                __designTimeSelection(VStack(alignment: .leading, spacing: __designTimeInteger("#2263_3", fallback: 8)) {
                                    __designTimeSelection(Text(__designTimeSelection(dateFormatter.string(from: __designTimeSelection(date, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[0].arg[0].value.modifier[0].arg[0].value")), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[0].arg[0].value"))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal)
                                        .id(__designTimeSelection(date, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[0].modifier[3].arg[0].value")), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[0]") // 给每个日期一个 ID，方便滚动

                                    __designTimeSelection(ForEach(__designTimeSelection(dayEvents.sorted(by: { $0.startDate < $1.startDate }), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1].arg[0].value")) { event in
                                        __designTimeSelection(HStack {
                                            __designTimeSelection(Text(__designTimeSelection(timeFormatter.string(from: __designTimeSelection(event.startDate, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1].arg[1].value.[0].arg[0].value.[0].arg[0].value.modifier[0].arg[0].value")), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1].arg[1].value.[0].arg[0].value.[0].arg[0].value"))
                                                .foregroundColor(.gray)
                                                .frame(width: __designTimeInteger("#2263_4", fallback: 60), alignment: .leading), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1].arg[1].value.[0].arg[0].value.[0]")

                                            __designTimeSelection(Text(__designTimeSelection(event.title, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1].arg[1].value.[0].arg[0].value.[1].arg[0].value"))
                                                .padding(__designTimeInteger("#2263_5", fallback: 8))
                                                .foregroundColor(.white)
                                                .background(__designTimeSelection(getColor(for: __designTimeSelection(event, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1].arg[1].value.[0].arg[0].value.[1].modifier[2].arg[0].value.arg[0].value")), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1].arg[1].value.[0].arg[0].value.[1].modifier[2].arg[0].value"))
                                                .cornerRadius(__designTimeInteger("#2263_6", fallback: 8)), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1].arg[1].value.[0].arg[0].value.[1]")
                                        }
                                        .padding(.horizontal), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1].arg[1].value.[0]")
                                    }, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[1]")

                                    __designTimeSelection(Divider(), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0].arg[2].value.[2]")
                                }, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0].arg[2].value.[0]")
                            }, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0].arg[2].value.[0]")
                        }
                        .padding(.vertical), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].arg[0].value.[0]")
                    }
                    .onAppear {
                        __designTimeSelection(fetchEvents(), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].modifier[0].arg[0].value.[0]")
                        __designTimeSelection(DispatchQueue.main.asyncAfter(deadline: .now() + __designTimeFloat("#2263_7", fallback: 0.3)) {
                            if let today = scrollToDate {
                                __designTimeSelection(withAnimation {
                                    __designTimeSelection(proxy.scrollTo(__designTimeSelection(today, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].modifier[0].arg[0].value.[1].modifier[0].arg[1].value.[0].[0].[0].arg[0].value.[0].modifier[0].arg[0].value"), anchor: .top), "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].modifier[0].arg[0].value.[1].modifier[0].arg[1].value.[0].[0].[0].arg[0].value.[0]")
                                }, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].modifier[0].arg[0].value.[1].modifier[0].arg[1].value.[0].[0].[0]")
                            }
                        }, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0].modifier[0].arg[0].value.[1]")
                    }, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2].arg[0].value.[0]")
                }, "#2263.[3].[4].property.[0].[0].arg[0].value.[0].arg[0].value.[2]")
            }
            .navigationBarHidden(__designTimeBoolean("#2263_8", fallback: true)), "#2263.[3].[4].property.[0].[0].arg[0].value.[0]")
        }, "#2263.[3].[4].property.[0].[0]")
    }

    // MARK: - 日期分组
    private func groupedEventsWithEmptyDays() -> [(Date, [Event])] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: __designTimeSelection(currentMonth, "#2263.[3].[5].[1].value.[0]"))!
        let components = calendar.dateComponents([.year, .month], from: __designTimeSelection(currentMonth, "#2263.[3].[5].[2].value.modifier[0].arg[1].value"))
        let startOfMonth = calendar.date(from: __designTimeSelection(components, "#2263.[3].[5].[3].value.[0]"))!

        var result: [(Date, [Event])] = []

        let monthEvents = events.filter {
            __designTimeSelection(calendar.isDate(__designTimeSelection($0.date, "#2263.[3].[5].[5].value.modifier[0].arg[0].value.[0].modifier[0].arg[0].value"), equalTo: __designTimeSelection(currentMonth, "#2263.[3].[5].[5].value.modifier[0].arg[0].value.[0].modifier[0].arg[1].value"), toGranularity: .month), "#2263.[3].[5].[5].value.modifier[0].arg[0].value.[0]")
        }

        let eventDict = Dictionary(grouping: __designTimeSelection(monthEvents, "#2263.[3].[5].[6].value.arg[0].value"), by: { __designTimeSelection(calendar.startOfDay(for: __designTimeSelection($0.date, "#2263.[3].[5].[6].value.arg[1].value.[0].modifier[0].arg[0].value")), "#2263.[3].[5].[6].value.arg[1].value.[0]") })

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - __designTimeInteger("#2263_9", fallback: 1), to: __designTimeSelection(startOfMonth, "#2263.[3].[5].[7].[0]")) {
                let grouped = eventDict[__designTimeSelection(calendar.startOfDay(for: __designTimeSelection(date, "#2263.[3].[5].[7].[0].[0].[0].value.[0]")), "#2263.[3].[5].[7].[0].[0].[0].value.[0]")] ?? []
                __designTimeSelection(result.append((__designTimeSelection(date, "#2263.[3].[5].[7].[0].[0].[1].modifier[0].arg[0].value.[0]"), __designTimeSelection(grouped, "#2263.[3].[5].[7].[0].[0].[1].modifier[0].arg[0].value.[0]"))), "#2263.[3].[5].[7].[0].[0].[1]")
            }
        }

        return __designTimeSelection(result, "#2263.[3].[5].[8]")
    }

    // MARK: - 切换月份
    private func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: __designTimeInteger("#2263_10", fallback: -1), to: __designTimeSelection(currentMonth, "#2263.[3].[6].[0].[1]"))!
        __designTimeSelection(fetchEvents(), "#2263.[3].[6].[1]")
    }

    private func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: __designTimeInteger("#2263_11", fallback: 1), to: __designTimeSelection(currentMonth, "#2263.[3].[7].[0].[1]"))!
        __designTimeSelection(fetchEvents(), "#2263.[3].[7].[1]")
    }

    // MARK: - 活动读取
    private func fetchEvents() {
        __designTimeSelection(EventManager.shared.fetchEvents { result in
            switch result {
            case .success(let fetched):
                self.events = fetched
                self.scrollToDate = Calendar.current.startOfDay(for: __designTimeSelection(Date(), "#2263.[3].[8].[0].modifier[0].arg[0].value.[0].[0].[1].[0]")) // 自动定位今天
            case .failure(let error):
                __designTimeSelection(print("读取失败: \(__designTimeSelection(error.localizedDescription, "#2263.[3].[8].[0].modifier[0].arg[0].value.[0].[1].[0].arg[0].value.[1].value.arg[0].value"))"), "#2263.[3].[8].[0].modifier[0].arg[0].value.[0].[1].[0]")
            }
        }, "#2263.[3].[8].[0]")
    }

    // MARK: - 活动颜色
    private func getColor(for event: Event) -> Color {
        if event.creatorOpenid == currentUserOpenid {
            return .red
        } else if event.openChecked {
            return .green
        } else {
            return .blue
        }
    }
}

// MARK: - 日期格式工具
private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M.d（E）"
    return __designTimeSelection(f, "#2263.[4].value.[1]")
}()

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return __designTimeSelection(f, "#2263.[5].value.[1]")
}()

private let monthFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy · MM"
    return __designTimeSelection(f, "#2263.[6].value.[1]")
}()


// MARK: - 预览

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        __designTimeSelection(CalendarView(), "#2263.[7].[0].property.[0].[0]")
    }
}
