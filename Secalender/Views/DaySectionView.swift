//
//  DaySectionView.swift
//  Secalender
//
//  Created by 林平 on 2025/3/28.
//

import SwiftUI

struct DaySectionView: View {
    let date: Date
    let events: [Event]
    let currentUserOpenid: String
    let dateFormatter: DateFormatter
    let timeFormatter: DateFormatter

    var body: some View {
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

            if events.isEmpty {
                Divider().padding(.horizontal)
            } else {
                ForEach(events.sorted(by: { 
                    ($0.startDateTime ?? .distantPast) < ($1.startDateTime ?? .distantPast) 
                })) { event in
                    let destination: AnyView = {
                        if event.creatorOpenid == currentUserOpenid {
                            return AnyView(EventEditView(viewModel: EventDetailViewModel(event: event)))
                        } else {
                            return AnyView(EventShareView(event: event))
                        }
                    }()

                    NavigationLink(destination: destination) {
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
                                .background(getColor(for: event))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                }
                Divider().padding(.horizontal)
            }
        }
    }

    private func getColor(for event: Event) -> Color {
        let now = Date()
        let isPast = (event.endDateTime ?? .distantPast) < now

        if event.creatorOpenid == currentUserOpenid {
            return isPast ? (Color(hex: "#CCCCCC") ?? .gray) : (Color(hex: "#FF6280") ?? .pink)
        }
        if event.isOpenChecked {
            return isPast ? (Color(hex: "#AAAAAA") ?? .gray) : (Color(hex: "#5EDA74") ?? .green)
        }
        // 群组相关逻辑已移除
        return Color.gray.opacity(0.3)
    }
}

private let monthFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy · MM"
    return f
}()
