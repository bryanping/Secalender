//
//  FriendEventsView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/29.
//

import SwiftUI
import Firebase

struct FriendEventsView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var friendEmails: [String] = []
    @State private var friendEvents: [Event] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(groupedFriendEvents(), id: \.0) { (date, events) in
                    SharedEventSectionView(
                        date: date,
                        events: events,
                        currentUserOpenid: userManager.userOpenId,
                        allowNavigation: true
                    )
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            loadFriendData()
        }
    }

    // 加载好友列表
    private func loadFriendData() {
        let db = Firestore.firestore()
        db.collection("friendships")
            .whereField("owner", isEqualTo: userManager.userOpenId)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    self.friendEmails = documents.compactMap { $0["friend"] as? String }
                    loadEvents()
                } else if let error = error {
                    print("获取好友失败：\(error.localizedDescription)")
                }
            }
    }

    // 加载好友公开活动
    private func loadEvents() {
        let db = Firestore.firestore()
        db.collection("events")
            .whereField("openChecked", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    let all = documents.compactMap { try? $0.data(as: Event.self) }
                    self.friendEvents = all.filter { friendEmails.contains($0.creatorOpenid) }
                } else if let error = error {
                    print("获取活动失败：\(error.localizedDescription)")
                }
            }
    }

    // 分组并按日期排序
    private func groupedFriendEvents() -> [(Date, [Event])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: friendEvents, by: { calendar.startOfDay(for: $0.startDate) })
        return dict.keys.sorted().map { date in
            (date, dict[date] ?? [])
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
