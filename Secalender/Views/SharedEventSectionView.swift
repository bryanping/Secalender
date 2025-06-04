//
//  SharedEventSectionView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/28.
//

import SwiftUI

struct SharedEventSectionView: View {
    let date: Date
    let events: [Event]
    let currentUserOpenid: String
    var allowNavigation: Bool = true

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

            ForEach(events.sorted(by: { $0.startDate < $1.startDate })) { event in
                let isMine = event.creatorOpenid == currentUserOpenid
                let destination: AnyView = {
                    if isMine {
                        return AnyView(EventEditView(viewModel: EventDetailViewModel(event: event)))
                    } else {
                        return AnyView(EventShareView(event: event))
                    }
                }()

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
            Text(timeFormatter.string(from: event.startDate))
                .foregroundColor(.gray)
                .font(.subheadline)
                .frame(width: 60, alignment: .trailing)

            Text(event.title)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isMine ? Color.gray : getColor(for: event))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }

    private func getColor(for event: Event) -> Color {
        if event.creatorOpenid == currentUserOpenid {
            return .gray
        } else if event.openChecked {
            return .blue
        } else {
            return .red
        }
    }
}

// 可共用格式器
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
