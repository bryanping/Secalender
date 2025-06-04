//
//  SharedEventSectionView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/28.
//
import SwiftUI
import Foundation
import Firebase

struct SharedEventSectionView: View {
    let date: Date
    let events: [Event]
    let currentUserOpenid: String
    var allowNavigation: Bool = true
    var onEventUpdated: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let isToday = Calendar.current.isDateInToday(date)

            HStack {
                Text(dateFormatter.string(from: date))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(isToday ? .accentColor : .primary)
                if isToday {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal)
            .id(date)

            // 如果没有事件，不显示任何内容
            if events.isEmpty {
                // 空状态 - 不显示任何内容
            }
            
            ForEach(events.sorted(by: { 
                ($0.startDateTime ?? .distantPast) < ($1.startDateTime ?? .distantPast) 
            })) { event in
                let isMine = event.creatorOpenid == currentUserOpenid
                // 无论是否是自己创建的事件，都导航到EventShareView
                let destination = AnyView(EventShareView(event: event, onEventUpdated: onEventUpdated))

                Group {
                    if allowNavigation {
                        NavigationLink(destination: destination) {
                            eventRow(event: event, isMine: isMine)
                        }
                    } else {
                        eventRow(event: event, isMine: isMine)
                    }
                }
            }

            Divider().padding(.horizontal)
        }
    }

    @ViewBuilder
    private func eventRow(event: Event, isMine: Bool) -> some View {
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
                .background(determineColor(for: event))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }

    private func determineColor(for event: Event) -> Color {
        let now = Date()
        if let end = event.endDateTime, now > end {
            return .gray
        }
        if event.creatorOpenid == currentUserOpenid {
            return .pink
        }
        if event.isOpenChecked {
            return .green
        }
        return .blue
    }
}

// MARK: - Formatter 共用

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

