//
//  FriendEventsView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/29.
//

import SwiftUI
import Firebase

struct FriendEventsView: View {
    @State private var friendEmails: [String] = []
    @State private var friendEvents: [Event] = []
    @State private var currentUserOpenid: String = "current_user_openid"

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(groupedFriendEvents(), id: \.0) { (date, events) in
                    SharedEventSectionView(date: date, events: events, currentUserOpenid: currentUserOpenid)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            loadFriendData()
        }
    }

    private func loadFriendData() {
        let db = Firestore.firestore()
        db.collection("friendships")
            .whereField("owner", isEqualTo: currentUserOpenid)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    self.friendEmails = documents.compactMap { $0["friend"] as? String }
                    loadEvents()
                }
            }
    }

    private func loadEvents() {
        let db = Firestore.firestore()
        db.collection("events")
            .whereField("openChecked", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    let all = documents.compactMap { try? $0.data(as: Event.self) }
                    self.friendEvents = all.filter { friendEmails.contains($0.creatorOpenid) }
                }
            }
    }

    private func groupedFriendEvents() -> [(Date, [Event])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: friendEvents, by: { calendar.startOfDay(for: $0.startDate) })
        return dict.keys.sorted().map { date in
            (date, dict[date] ?? [])
        }
    }
}
