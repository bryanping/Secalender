//
//  FriendEventsView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/29.
//

import SwiftUI

struct FriendEventsView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var allEvents: [Event] = []
    @State private var filteredEvents: [Event] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(groupedEventsWithEmptyDays(), id: \.0) { (date, dayEvents) in
                    VStack(alignment: .leading, spacing: 8) {
                        let isToday = Calendar.current.isDateInToday(date)

                        HStack {
                            Text(dateFormatter.string(from: date))
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(isToday ? .accentColor : .primary)

                            if isToday {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(.horizontal)
                        .id(date)

                        if dayEvents.isEmpty {
                            Divider().padding(.horizontal)
                        } else {
                            ForEach(dayEvents.sorted(by: { 
                                ($0.startDateTime ?? .distantPast) < ($1.startDateTime ?? .distantPast) 
                            })) { event in
                                NavigationLink(destination: EventShareView(event: event)) {
                                    HStack(spacing: 12) {
                                        if let start = event.startDateTime {
                                            Text(timeFormatter.string(from: start))
                                            .foregroundColor(.gray)
                                            .font(.subheadline)
                                            .frame(width: 60, alignment: .trailing)
                                        }
                                        Text(event.title)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            Divider().padding(.horizontal)
                        }
                    }
                }

                Text("邀請更多朋友加入")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
            }
            .padding(.vertical)
        }
        .navigationTitle("朋友 & 邀請行程")
        .refreshable { await refreshEvents() }
        .onAppear {
            Task { await refreshEvents() }
        }
    }

    private func groupedEventsWithEmptyDays() -> [(Date, [Event])] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: Date())!
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components)!

        var result: [(Date, [Event])] = []
        let eventDict = Dictionary(grouping: filteredEvents, by: { $0.dateObj ?? Date() })

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let grouped = eventDict[calendar.startOfDay(for: date)] ?? []
                result.append((date, grouped))
            }
        }

        return result
    }

    private func refreshEvents() async {
        do {
            let events = try await EventManager.shared.fetchEvents()

            let myId = userManager.userOpenId
            let role = userManager.userRole

            let filtered = await EventAccessManager.shared.filterEventsForCurrentUser(
                events,
                currentUserOpenId: myId,
                userRole: role
            ) { creatorId in
                FriendManager.shared.isFriend(with: creatorId)
            }

            await MainActor.run {
                self.allEvents = events
                self.filteredEvents = filtered.filter { $0.creatorOpenid != myId }
            }
        } catch {
            print("取得事件失敗：\(error.localizedDescription)")
        }
    }

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
}

struct FriendEventsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendEventsView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
