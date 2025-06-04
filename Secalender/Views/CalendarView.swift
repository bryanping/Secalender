import SwiftUI
import Firebase
import FirebaseFirestore

struct CalendarView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var currentMonth: Date = Date()
    @State private var events: [Event] = []
    @State private var scrollToDate: Date?
    @State private var isRefreshing = false
    @State private var showCreateEvent = false
    @State private var selectedDateForNewEvent: Date?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 月份切换
                HStack {
                    Spacer()
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                    }
                    //Spacer()
                    Text(monthFormatter.string(from: currentMonth))
                        .font(.headline)
                    //Spacer()
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

                Divider()

                // ScrollView + 下拉刷新
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(groupedEventsWithEmptyDays(), id: \.0) { (date, dayEvents) in
                                SharedEventSectionView(
                                    date: date,
                                    events: dayEvents,
                                    currentUserOpenid: userManager.userOpenId,
                                    allowNavigation: true
                                )
                                .onTapGesture(count: 2) {
                                    self.selectedDateForNewEvent = date
                                    self.showCreateEvent = true
                                }
                            }

                        }
                        .padding(.vertical)
                        .refreshable {
                            await refreshEvents()
                        }
                    }
                    .onAppear {
                        loadEvents()
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
            //.navigationTitle("")
            //.navigationBarHidden(false)
            
            .sheet(isPresented: $showCreateEvent) {
                NavigationView {
                    EventCreateView(viewModel: EventDetailViewModel(event:
                        Event(date: selectedDateForNewEvent ?? Date(),
                              startDate: selectedDateForNewEvent ?? Date(),
                              endDate: Calendar.current.date(byAdding: .hour, value: 1, to: selectedDateForNewEvent ?? Date())!
                        )
                    )) {
                        self.showCreateEvent = false
                        self.loadEvents()
                    }
                }
            }
        }
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
        loadEvents()
    }

    private func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)!
        loadEvents()
    }

    private func loadEvents() {
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

    private func refreshEvents() async {
        await withCheckedContinuation { continuation in
            EventManager.shared.fetchEvents { result in
                switch result {
                case .success(let fetched):
                    self.events = fetched
                    self.scrollToDate = Calendar.current.startOfDay(for: Date())
                case .failure(let error):
                    print("刷新失败: \(error.localizedDescription)")
                }
                continuation.resume()
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
