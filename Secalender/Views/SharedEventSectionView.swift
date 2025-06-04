//
//  SharedEventSectionView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/28.
//
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
        VStack(alignment: .leading, spacing: 8) {
            // 日期标题
            dateHeaderView
            
            // 事件列表
            ForEach(events.sorted(by: { $0.startDate < $1.startDate })) { event in
                eventRowContent(event: event)
            }
            
            Divider().padding(.horizontal)
        }
    }
    
    // 日期标题视图
    private var dateHeaderView: some View {
        let isToday = Calendar.current.isDateInToday(date)
        
        return HStack {
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
    }
    
    // 事件行内容
    @ViewBuilder
    private func eventRowContent(event: Event) -> some View {
        let isMine = event.creatorOpenid == currentUserOpenid
        
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title.isEmpty ? "(未命名事件)" : event.title)
                    .font(.headline)
                
                Text("\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if !isMine {
                    Text("由他人發起")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .modifier(EventRowModifier(
            event: event,
            isMine: isMine,
            allowNavigation: allowNavigation,
            currentUserOpenid: currentUserOpenid
        ))
    }
}

// 事件行修饰器，处理导航和样式
private struct EventRowModifier: ViewModifier {
    let event: Event
    let isMine: Bool
    let allowNavigation: Bool
    let currentUserOpenid: String
    
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
            .shadow(radius: 0.5)
            .background(
                NavigationLink(
                    destination: destinationView,
                    label: { EmptyView() }
                )
                .opacity(allowNavigation ? 1 : 0)
            )
    }
    
    @ViewBuilder
    private var destinationView: some View {
        if isMine {
            EventEditView(viewModel: EventDetailViewModel(event: event))
        } else {
            EventShareView(event: event)
        }
    }
}
