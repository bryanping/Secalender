//
//  FriendDetailView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct FriendDetailView: View {
    let friendId: String
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    // 好友基本信息
    @State private var friendInfo: FriendDetailInfo?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // 朋友资料（可编辑）
    @State private var remarksName: String = ""
    @State private var remarksPhone: String = ""
    @State private var privacyLevel: String = "normal" // normal, limited, full
    @State private var isEditing = false
    @State private var showSaveAlert = false
    
    // 好友行程
    @State private var sharedEvents: [Event] = []
    @State private var isLoadingEvents = false
    
    // 好友介面 2.0：分享活動按鈕、行程/主題/模板分頁
    @State private var showShareActivitySheet = false
    enum DetailTab: String, CaseIterable {
        case trips
        case themes
        case templates
        var titleKey: String {
            switch self {
            case .trips: return "friend_detail.tab_trips"
            case .themes: return "friend_detail.tab_themes"
            case .templates: return "friend_detail.tab_templates"
            }
        }
    }
    @State private var selectedTab: DetailTab = .trips
    
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView("friends.loading".localized())
                            .frame(maxWidth: .infinity, minHeight: 400)
                    } else if let info = friendInfo {
                        friendBasicInfoSection(info: info)
                        
                        // 主操作：分享活動（取代發送訊息）
                        Button {
                            showShareActivitySheet = true
                        } label: {
                            Text("event_share_action.share_event".localized())
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        friendDataSection(info: info)
                        
                        // 分頁：行程 / 主題 / 模板
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("", selection: $selectedTab) {
                                ForEach(DetailTab.allCases, id: \.self) { tab in
                                    Text(tab.titleKey.localized()).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            switch selectedTab {
                            case .trips:
                                sharedEventsSection()
                            case .themes:
                                friendThemesPlaceholder()
                            case .templates:
                                friendTemplatesPlaceholder()
                            }
                        }
                    } else {
                        Text("friend_detail.load_failed".localized())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 400)
                    }
                }
                .padding()
            }
        .navigationTitle("friend_detail.title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    HStack(spacing: 12) {
                        Button("friend_detail.save".localized()) {
                            Task { await saveFriendData() }
                        }
                        Button("common.cancel".localized()) {
                            isEditing = false
                        }
                    }
                } else if friendInfo != nil {
                    Menu {
                        Button {
                            isEditing = true
                        } label: {
                            Label("friend_detail.edit_friend_profile".localized(), systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .task {
            await loadFriendDetail()
        }
        .sheet(isPresented: $showShareActivitySheet) {
            ShareActivitiesToFriendSheet(
                friendId: friendId,
                friendName: friendInfo?.name ?? friendInfo?.email ?? ""
            )
            .environmentObject(userManager)
        }
        .alert("friend_detail.save_success".localized(), isPresented: $showSaveAlert) {
            Button("common.confirm".localized(), role: .cancel) {}
        }
    }
    
    @ViewBuilder
    private func friendThemesPlaceholder() -> some View {
        Text("friend_detail.themes_placeholder".localized())
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
    }
    
    @ViewBuilder
    private func friendTemplatesPlaceholder() -> some View {
        Text("friend_detail.templates_placeholder".localized())
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
    }
    
    // MARK: - 第一栏：基本信息
    @ViewBuilder
    private func friendBasicInfoSection(info: FriendDetailInfo) -> some View {
        VStack(spacing: 16) {
            // 头像
            if let photoUrl = info.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(spacing: 8) {
                // 名称
                Text(info.name ?? info.email ?? "未知用户")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // 昵称
                if let alias = info.alias, !alias.isEmpty {
                    Text(alias)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                // ID
                Text("ID: \(info.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 地区
                if let region = info.region, !region.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(region)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 第二栏：朋友资料
    @ViewBuilder
    private func friendDataSection(info: FriendDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("friend_detail.friend_profile".localized())
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // 备注名
                HStack {
                    Text("备注名")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    if isEditing {
                        TextField("请输入备注名", text: $remarksName)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(remarksName.isEmpty ? "未设置" : remarksName)
                            .foregroundColor(remarksName.isEmpty ? .secondary : .primary)
                    }
                }
                
                // 电话
                HStack {
                    Text("电话")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    if isEditing {
                        TextField("请输入电话", text: $remarksPhone)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.phonePad)
                    } else {
                        Text(remarksPhone.isEmpty ? "未设置" : remarksPhone)
                            .foregroundColor(remarksPhone.isEmpty ? .secondary : .primary)
                    }
                }
                
                // 权限（隐私设定）
                HStack {
                    Text("权限")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    if isEditing {
                        Picker("权限", selection: $privacyLevel) {
                            Text("普通").tag("normal")
                            Text("受限").tag("limited")
                            Text("完整").tag("full")
                        }
                        .pickerStyle(.menu)
                    } else {
                        Text(privacyLevelText)
                            .foregroundColor(.primary)
                    }
                }
                
                // 新增时间
                HStack {
                    Text("新增时间")
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    Text(info.addedDateText)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var privacyLevelText: String {
        switch privacyLevel {
        case "normal": return "普通"
        case "limited": return "受限"
        case "full": return "完整"
        default: return "普通"
        }
    }
    
    // MARK: - 第三栏：好友行程
    @ViewBuilder
    private func sharedEventsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("friend_detail.shared_trips".localized())
                .font(.headline)
                .fontWeight(.semibold)
            
            if isLoadingEvents {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if sharedEvents.isEmpty {
                Text("friend_detail.no_trips".localized())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(sharedEvents, id: \.id) { event in
                    NavigationLink(destination: EventShareView(event: event)
                        .environmentObject(userManager)) {
                        FriendEventRowView(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 第四栏：过往行程轨迹分享
    @ViewBuilder
    private func trajectorySection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("过往行程轨迹分享")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("功能开发中...")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 数据加载
    private func loadFriendDetail() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }
        
        do {
            let db = Firestore.firestore()
            let currentUserId = userManager.userOpenId
            
            // 1. 获取好友基本信息（先以 document ID = 用戶 UID 讀取，與 UserManager/EditProfileView 一致）
            var userData: [String: Any]?
            let docSnapshot = try await db.collection("users").document(friendId).getDocument()
            if docSnapshot.exists, let data = docSnapshot.data() {
                userData = data
            }
            if userData == nil {
                let userSnapshot = try await db.collection("users")
                    .whereField("openid", isEqualTo: friendId)
                    .limit(to: 1)
                    .getDocuments()
                if let first = userSnapshot.documents.first {
                    userData = first.data()
                }
            }
            guard let userData = userData else {
                await MainActor.run { errorMessage = "找不到好友信息" }
                return
            }
            
            // 2. 获取朋友关系数据（备注名、电话、新增时间等）；失败时仍用用户资料显示
            var friendData: [String: Any] = [:]
            do {
                let friendDoc = try await db.collection("friends")
                    .whereField("owner", isEqualTo: currentUserId)
                    .whereField("friend", isEqualTo: friendId)
                    .limit(to: 1)
                    .getDocuments()
                friendData = friendDoc.documents.first?.data() ?? [:]
            } catch {
                print("加载朋友关系失败（使用默认）: \(error.localizedDescription)")
            }
            let sinceTimestamp = friendData["since"] as? Timestamp
            let addedDate = sinceTimestamp?.dateValue() ?? Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy年MM月dd日"
            let addedDateText = dateFormatter.string(from: addedDate)
            
            await MainActor.run {
                friendInfo = FriendDetailInfo(
                    id: friendId,
                    name: (userData["name"] as? String) ?? (userData["displayName"] as? String) ?? (userData["display_name"] as? String),
                    alias: userData["alias"] as? String,
                    email: userData["email"] as? String,
                    photoUrl: userData["photo_url"] as? String ?? userData["photoUrl"] as? String,
                    region: userData["region"] as? String,
                    addedDate: addedDate,
                    addedDateText: addedDateText
                )
                
                // 设置朋友资料
                remarksName = friendData["remarksname"] as? String ?? ""
                remarksPhone = friendData["remarkphone"] as? String ?? ""
                privacyLevel = friendData["privacy"] as? String ?? "normal"
            }
            
            // 3. 加载好友行程
            await loadSharedEvents()
            
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            print("加载好友详情失败: \(error.localizedDescription)")
        }
    }
    
    // 加载好友分享的行程
    private func loadSharedEvents() async {
        await MainActor.run {
            isLoadingEvents = true
        }
        
        do {
            let db = Firestore.firestore()
            let currentUserId = userManager.userOpenId
            var eventIds: Set<Int> = []
            var events: [Event] = []
            
            // 1. 获取好友分享给我的行程
            let sharesSnapshot = try await db.collection("event_shares")
                .whereField("receiverId", isEqualTo: currentUserId)
                .whereField("senderId", isEqualTo: friendId)
                .getDocuments()
            
            for shareDoc in sharesSnapshot.documents {
                let shareData = shareDoc.data()
                if let eventId = shareData["eventId"] as? Int {
                    eventIds.insert(eventId)
                }
            }
            
            // 2. 获取好友的公开行程（openChecked == 1）
            let friendEventsSnapshot = try await db.collection("users")
                .document(friendId)
                .collection("events")
                .whereField("openChecked", isEqualTo: 1)
                .getDocuments()
            
            for doc in friendEventsSnapshot.documents {
                if let event = parseEventFromDocument(doc),
                   let eventId = event.id {
                    if !eventIds.contains(eventId) {
                        eventIds.insert(eventId)
                    }
                }
            }
            
            // 3. 获取所有事件详情
            for eventId in eventIds {
                let eventDoc = try? await db.collection("users")
                    .document(friendId)
                    .collection("events")
                    .whereField("id", isEqualTo: eventId)
                    .limit(to: 1)
                    .getDocuments()
                
                if let eventDoc = eventDoc?.documents.first,
                   let event = parseEventFromDocument(eventDoc),
                   event.deleted != 1 {
                    events.append(event)
                }
            }
            
            // 按日期排序
            events.sort { event1, event2 in
                let date1 = event1.dateObj ?? Date.distantPast
                let date2 = event2.dateObj ?? Date.distantPast
                return date1 < date2
            }
            
            await MainActor.run {
                sharedEvents = events
                isLoadingEvents = false
            }
        } catch {
            print("加载好友行程失败: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingEvents = false
            }
        }
    }
    
    // 解析事件文档
    private func parseEventFromDocument(_ doc: QueryDocumentSnapshot) -> Event? {
        let data = doc.data()
        
        var event = Event()
        
        // 基本字段
        event.id = data["id"] as? Int ?? abs(doc.documentID.hashValue)
        event.title = data["title"] as? String ?? ""
        event.creatorOpenid = data["creatorOpenid"] as? String ?? ""
        event.color = data["color"] as? String ?? "#FF0000"
        
        // 处理date字段：可能是String或Timestamp
        if let dateString = data["date"] as? String {
            event.date = dateString
        } else if let timestamp = data["date"] as? Timestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            event.date = formatter.string(from: timestamp.dateValue())
        } else {
            event.date = ""
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
        event.groupId = data["groupId"] as? String
        event.isAllDay = data["isAllDay"] as? Bool ?? false
        event.repeatType = data["repeatType"] as? String ?? "never"
        event.calendarComponent = data["calendarComponent"] as? String ?? "default"
        event.travelTime = data["travelTime"] as? String
        event.invitees = data["invitees"] as? [String]
        
        return event
    }
    
    // 保存朋友资料
    private func saveFriendData() async {
        do {
            let db = Firestore.firestore()
            let currentUserId = userManager.userOpenId
            
            // 查找朋友关系文档
            let friendDoc = try await db.collection("friends")
                .whereField("owner", isEqualTo: currentUserId)
                .whereField("friend", isEqualTo: friendId)
                .limit(to: 1)
                .getDocuments()
            
            if let doc = friendDoc.documents.first {
                var updateData: [String: Any] = [:]
                if !remarksName.isEmpty {
                    updateData["remarksname"] = remarksName
                }
                if !remarksPhone.isEmpty {
                    updateData["remarkphone"] = remarksPhone
                }
                updateData["privacy"] = privacyLevel
                
                try await doc.reference.updateData(updateData)
                
                await MainActor.run {
                    isEditing = false
                    showSaveAlert = true
                }
            }
        } catch {
            print("保存朋友资料失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 好友详情数据模型
struct FriendDetailInfo {
    let id: String
    let name: String?
    let alias: String?
    let email: String?
    let photoUrl: String?
    let region: String?
    let addedDate: Date
    let addedDateText: String
}

// MARK: - 事件行视图
struct FriendEventRowView: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if !event.date.isEmpty {
                        Label(event.date, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !event.startTime.isEmpty {
                        Label(event.startTime, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !event.destination.isEmpty {
                    Label(event.destination, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
