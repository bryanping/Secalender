// GroupEventsView.swift

import SwiftUI
import Firebase

/// 顯示用戶加入的社群中公開活動
struct GroupEventsView: View {
    let groupId: String?  // 可選的特定社群 ID，如果為 nil 則顯示所有社群活動
    
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var groupIds: [String] = []
    @State private var groupEvents: [Event] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(groupId: String? = nil) {
        self.groupId = groupId
    }

    var body: some View {
        VStack {
            if userManager.userOpenId.isEmpty {
                ProgressView("加载中...").padding()
            } else if isLoading {
                ProgressView().padding()
            } else if let err = errorMessage {
                Text(err).foregroundColor(.red)
            } else if groupIds.isEmpty && groupId == nil {
                VStack {
                    Spacer()
                    Text("尚未加入任何社群")
                        .foregroundColor(.gray)
                        .font(.body)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if groupEvents.isEmpty {
                            Text("尚未有社群活動")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(groupedEventsWithEmptyDays(), id: \.0) { (date, dayEvents) in
                                VStack(alignment: .leading, spacing: 8) {
                                    let isToday = Calendar.current.isDateInToday(date)
                                    HStack {
                                        Text(dateFormatter.string(from: date))
                                            .font(.footnote)
                                            .fontWeight(.semibold)
                                            .foregroundColor(isToday ? .accentColor : .primary)
                                        if isToday {
                                            Image(systemName: "star.fill").foregroundColor(.yellow)
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
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle(groupId != nil ? "社群活動" : "社群活動")
        .onAppear { Task { await refreshEvents() } }
        .refreshable { await refreshEvents() }
    }

    /// 將活動依當月日期分組，無活動的日期也會返回
    private func groupedEventsWithEmptyDays() -> [(Date, [Event])] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: Date())!
        let comps = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: comps)!
        var result: [(Date, [Event])] = []
        let eventDict = Dictionary(grouping: groupEvents, by: { $0.dateObj ?? Date() })
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                let grouped = eventDict[calendar.startOfDay(for: date)] ?? []
                result.append((date, grouped))
            }
        }
        return result
    }

    /// 從 Firestore 載入社群列表與公開活動
    private func refreshEvents() async {
        guard !userManager.userOpenId.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let db = Firestore.firestore()
            var ids: [String] = []
            
            if let specificGroupId = groupId {
                // 如果指定了特定社群 ID，只使用該社群
                ids = [specificGroupId]
                groupIds = ids
            } else {
                // 取出當前用戶參與的社群 ID
                let groupSnapshot = try await db.collection("groups")
                    .whereField("members", arrayContains: userManager.userOpenId)
                    .getDocuments()
                ids = groupSnapshot.documents.map { $0.documentID }
                groupIds = ids
            }
            
            guard !ids.isEmpty else {
                groupEvents = []
                isLoading = false
                return
            }
            
            // 從 groups/{groupId}/groupEvents 讀取社群活動
            var events: [Event] = []
            for groupId in ids {
                let groupEventsSnapshot = try await db.collection("groups")
                    .document(groupId)
                    .collection("groupEvents")
                    .whereField("openChecked", isEqualTo: 1)  // 只讀取公開的社群活動
                    .getDocuments()
                
                for doc in groupEventsSnapshot.documents {
                    let data = doc.data()
                    
                    // 建立 Event，解析必要欄位
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
                    
                    // 跳過已刪除的事件
                    if deleted == 1 {
                        continue
                    }
                    
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
                    event.groupId = groupId    // 設置 groupId
                    events.append(event)
                }
            }
            groupEvents = events
        } catch {
            errorMessage = error.localizedDescription
            groupEvents = []
        }
        isLoading = false
    }

    // 日期格式器
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
