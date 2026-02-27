//
//  CommunityTripsFeedView.swift
//  Secalender
//
//  顯示最新公開行程與關注社群行程的 feed
//

import SwiftUI
import Firebase
import FirebaseFirestore

/// 行程來源類型
enum TripSource {
    case friend(userId: String)
    case group(groupId: String)
}

/// 帶來源資訊的行程項目
struct FeedTripItem: Identifiable {
    let id: String
    let event: Event
    let source: TripSource
    let creatorDisplayName: String?
    let groupName: String?
    
    var sortDate: Date { event.dateObj ?? .distantPast }
}

/// 最新公開行程、關注社群行程的 feed 視圖
struct CommunityTripsFeedView: View {
    let groupIds: [String]
    let friendIds: [String]
    let currentUserId: String
    var refreshTrigger: UUID = UUID()
    
    @State private var feedItems: [FeedTripItem] = []
    @State private var isLoading = false
    @State private var creatorNames: [String: String] = [:]
    @State private var groupNames: [String: String] = [:]
    
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
        content
            .task(id: "\(groupIds.joined(separator: ","))-\(friendIds.joined(separator: ","))-\(refreshTrigger)") {
                await refresh()
            }
    }
    
    @ViewBuilder
    private var content: some View {
        if isLoading && feedItems.isEmpty {
            ProgressView("friends.loading".localized())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if feedItems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("group_events.no_activities".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(feedItems) { item in
                    feedCard(for: item)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
    }
    
    @ViewBuilder
    private func feedCard(for item: FeedTripItem) -> some View {
        NavigationLink(destination: EventShareView(event: item.event)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .blue.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(creatorDisplayName(for: item))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        if let groupName = item.groupName ?? groupNames[item.event.groupId ?? ""] {
                            Text(groupName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let date = item.event.dateObj {
                        Text(dateFormatter.string(from: date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(item.event.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if !item.event.destination.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(item.event.destination)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let start = item.event.startDateTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(timeFormatter.string(from: start))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task(id: item.id) {
            await loadCreatorAndGroupNames(for: item)
        }
    }
    
    private func creatorDisplayName(for item: FeedTripItem) -> String {
        if let name = item.creatorDisplayName { return name }
        if let name = creatorNames[item.event.creatorOpenid] { return name }
        return item.event.creatorOpenid.isEmpty ? "groups.unknown_member".localized() : "@\(item.event.creatorOpenid.prefix(8))"
    }
    
    private func loadCreatorAndGroupNames(for item: FeedTripItem) async {
        let creatorId = item.event.creatorOpenid
        guard !creatorId.isEmpty, creatorNames[creatorId] == nil else { return }
        
        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(creatorId)
                .getDocument()
            if let data = doc.data() {
                let name = (data["display_name"] as? String) ?? (data["alias"] as? String) ?? (data["name"] as? String) ?? (data["email"] as? String)
                await MainActor.run {
                    if let n = name { creatorNames[creatorId] = n }
                }
            }
        } catch {
            print("載入創作者名稱失敗: \(error.localizedDescription)")
        }
        
        if let gid = item.event.groupId, groupNames[gid] == nil {
            do {
                let group = try await GroupManager.shared.getGroup(groupId: gid)
                await MainActor.run { groupNames[gid] = group.name }
            } catch {
                print("載入社群名稱失敗: \(error.localizedDescription)")
            }
        }
    }
    
    func refresh() async {
        guard !currentUserId.isEmpty else { return }
        isLoading = true
        feedItems = []
        
        do {
            let db = Firestore.firestore()
            var items: [FeedTripItem] = []
            
            // 1. 好友公開行程
            for friendId in friendIds {
                let snapshot = try await db.collection("users")
                    .document(friendId)
                    .collection("events")
                    .whereField("openChecked", isEqualTo: 1)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    if let event = parseEventFromDocument(doc, creatorId: friendId) {
                        items.append(FeedTripItem(
                            id: "friend-\(friendId)-\(event.id ?? 0)",
                            event: event,
                            source: .friend(userId: friendId),
                            creatorDisplayName: nil,
                            groupName: nil
                        ))
                    }
                }
            }
            
            // 2. 關注社群行程
            for groupId in groupIds {
                let snapshot = try await db.collection("groups")
                    .document(groupId)
                    .collection("groupEvents")
                    .whereField("openChecked", isEqualTo: 1)
                    .getDocuments()
                
                var group: CommunityGroup?
                do {
                    group = try await GroupManager.shared.getGroup(groupId: groupId)
                } catch { }
                
                for doc in snapshot.documents {
                    if let event = parseGroupEventFromDocument(doc, groupId: groupId) {
                        items.append(FeedTripItem(
                            id: "group-\(groupId)-\(event.id ?? 0)",
                            event: event,
                            source: .group(groupId: groupId),
                            creatorDisplayName: nil,
                            groupName: group?.name
                        ))
                    }
                }
            }
            
            items.sort { $0.sortDate > $1.sortDate }
            await MainActor.run { feedItems = items }
        } catch {
            print("載入行程 feed 失敗: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func parseEventFromDocument(_ doc: QueryDocumentSnapshot, creatorId: String) -> Event? {
        let data = doc.data()
        guard (data["deleted"] as? Int) != 1 else { return nil }
        
        var event = Event()
        event.id = data["id"] as? Int ?? abs(doc.documentID.hashValue)
        event.title = data["title"] as? String ?? ""
        event.creatorOpenid = creatorId
        event.color = data["color"] as? String ?? "#FF0000"
        
        if let dateString = data["date"] as? String {
            event.date = dateString
        } else if let timestamp = data["date"] as? Timestamp {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            event.date = f.string(from: timestamp.dateValue())
        }
        event.startTime = data["startTime"] as? String ?? ""
        event.endTime = data["endTime"] as? String ?? ""
        event.endDate = data["endDate"] as? String
        event.destination = data["destination"] as? String ?? ""
        event.mapObj = data["mapObj"] as? String ?? ""
        event.openChecked = data["openChecked"] as? Int ?? 0
        event.personChecked = data["personChecked"] as? Int ?? 0
        event.personNumber = data["personNumber"] as? Int
        event.sponsorType = data["sponsorType"] as? String
        event.category = data["category"] as? String
        event.createTime = data["createTime"] as? String ?? ""
        event.deleted = data["deleted"] as? Int
        event.information = data["information"] as? String
        event.isAllDay = data["isAllDay"] as? Bool ?? false
        event.repeatType = data["repeatType"] as? String ?? "never"
        event.calendarComponent = data["calendarComponent"] as? String ?? "default"
        event.travelTime = data["travelTime"] as? String
        event.invitees = data["invitees"] as? [String]
        
        return event
    }
    
    private func parseGroupEventFromDocument(_ doc: QueryDocumentSnapshot, groupId: String) -> Event? {
        let data = doc.data()
        guard (data["deleted"] as? Int) != 1 else { return nil }
        
        let id = data["id"] as? Int
        let title = data["title"] as? String ?? ""
        let creatorOpenid = data["creatorOpenid"] as? String ?? ""
        let color = data["color"] as? String ?? ""
        let date = data["date"] as? String ?? ""
        let startTime = data["startTime"] as? String ?? ""
        let endTime = data["endTime"] as? String ?? ""
        let endDate = data["endDate"] as? String
        let destination = data["destination"] as? String ?? ""
        let mapObj = data["mapObj"] as? String ?? ""
        let openChecked = data["openChecked"] as? Int ?? 0
        let personChecked = data["personChecked"] as? Int ?? 0
        let personNumber = data["personNumber"] as? Int
        let sponsorType = data["sponsorType"] as? String
        let category = data["category"] as? String
        let createTime = data["createTime"] as? String ?? ""
        let deleted = data["deleted"] as? Int
        let information = data["information"] as? String
        let isAllDay = data["isAllDay"] as? Bool ?? false
        let repeatType = data["repeatType"] as? String ?? "never"
        let calendarComponent = data["calendarComponent"] as? String ?? "default"
        let travelTime = data["travelTime"] as? String
        let invitees = data["invitees"] as? [String]
        
        var event = Event(
            id: id, title: title, creatorOpenid: creatorOpenid, color: color,
            date: date, startTime: startTime, endTime: endTime,
            endDate: endDate, destination: destination, mapObj: mapObj,
            openChecked: openChecked, personChecked: personChecked,
            personNumber: personNumber, sponsorType: sponsorType,
            category: category, createTime: createTime, deleted: deleted,
            information: information, isAllDay: isAllDay, repeatType: repeatType,
            calendarComponent: calendarComponent, travelTime: travelTime,
            invitees: invitees
        )
        event.groupId = groupId
        return event
    }
}
