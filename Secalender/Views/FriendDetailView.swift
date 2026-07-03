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
                            Label("event_share_action.share_event".localized(), systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                friendName: friendInfo.map { FriendDetailView.shareSheetName(for: $0) } ?? ""
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
    
    // MARK: - 第一栏：頭像與公開資訊
    @ViewBuilder
    private func friendBasicInfoSection(info: FriendDetailInfo) -> some View {
        let headline = info.profileHeadline
        let aliasLine = info.distinctAliasLine
        
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.12),
                        Color(.secondarySystemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 72)
                .frame(maxWidth: .infinity)
                
                Group {
                    if let photoUrl = info.photoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Circle()
                                .fill(Color(.systemGray4))
                        }
                    } else {
                        Circle()
                            .fill(Color(.systemGray4))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                .offset(y: 36)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 36)
            
            VStack(spacing: 8) {
                Text(headline.isEmpty ? "friends.unknown".localized() : headline)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let aliasLine {
                    Text(String(format: "friend_detail.alias_format".localized(), aliasLine))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            if info.hasPublicMetaRows {
                VStack(spacing: 0) {
                    if let region = info.region?.trimmingCharacters(in: .whitespacesAndNewlines), !region.isEmpty {
                        profileMetaRow(icon: "mappin.and.ellipse", text: region)
                        if info.hasNonEmptyEmail {
                            Divider().padding(.leading, 44)
                        }
                    }
                    if let email = info.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
                        profileMetaRow(icon: "envelope.fill", text: email)
                    }
                }
                .padding(.vertical, 4)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
    
    private func profileMetaRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - 第二栏：僅你可見的朋友資料（對齊分組列表）
    @ViewBuilder
    private func friendDataSection(info: FriendDetailInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("friend_detail.friend_profile".localized())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                friendProfileFieldRow(
                    titleKey: "friend_detail.remarks_name",
                    isEditing: isEditing,
                    editContent: {
                        TextField("friend_detail.remarks_placeholder".localized(), text: $remarksName)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    },
                    displayText: remarksName.isEmpty ? "profile.not_set".localized() : remarksName,
                    displaySecondary: remarksName.isEmpty
                )
                Divider().padding(.leading, 16)
                friendProfileFieldRow(
                    titleKey: "friend_detail.phone_label",
                    isEditing: isEditing,
                    editContent: {
                        TextField("friend_detail.phone_placeholder".localized(), text: $remarksPhone)
                            .textFieldStyle(.plain)
                            .keyboardType(.phonePad)
                            .multilineTextAlignment(.trailing)
                    },
                    displayText: remarksPhone.isEmpty ? "profile.not_set".localized() : remarksPhone,
                    displaySecondary: remarksPhone.isEmpty
                )
                Divider().padding(.leading, 16)
                friendProfileFieldRow(
                    titleKey: "friend_detail.privacy_label",
                    isEditing: isEditing,
                    editContent: {
                        Picker("", selection: $privacyLevel) {
                            Text("friend_detail.privacy_normal".localized()).tag("normal")
                            Text("friend_detail.privacy_limited".localized()).tag("limited")
                            Text("friend_detail.privacy_full".localized()).tag("full")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    },
                    displayText: privacyLevelText,
                    displaySecondary: false
                )
                Divider().padding(.leading, 16)
                friendProfileReadOnlyRow(titleKey: "friend_detail.friends_since", value: info.addedDateText)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
    
    private func friendProfileFieldRow<Edit: View>(
        titleKey: String,
        isEditing: Bool,
        @ViewBuilder editContent: () -> Edit,
        displayText: String,
        displaySecondary: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(titleKey.localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 96, alignment: .leading)
            Group {
                if isEditing {
                    editContent()
                } else {
                    Text(displayText)
                        .font(.body)
                        .foregroundStyle(displaySecondary ? .secondary : .primary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private func friendProfileReadOnlyRow(titleKey: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(titleKey.localized())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 96, alignment: .leading)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private var privacyLevelText: String {
        switch privacyLevel {
        case "normal": return "friend_detail.privacy_normal".localized()
        case "limited": return "friend_detail.privacy_limited".localized()
        case "full": return "friend_detail.privacy_full".localized()
        default: return "friend_detail.privacy_normal".localized()
        }
    }
    
    private static func shareSheetName(for info: FriendDetailInfo) -> String {
        let h = info.profileHeadline
        if !h.isEmpty { return h }
        if let e = info.email?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty { return e }
        return ""
    }
    
    private static func trimmedString(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
    
    /// 與 FriendManager 一致：優先 display_name，並略過空字串的 name
    private static func resolvedUserDisplayName(from data: [String: Any]) -> String? {
        trimmedString(data["display_name"] as? String)
            ?? trimmedString(data["displayName"] as? String)
            ?? trimmedString(data["name"] as? String)
            ?? trimmedString(data["provider_display_name"] as? String)
            ?? trimmedString(data["alias"] as? String)
            ?? trimmedString(data["email"] as? String)
    }
    
    private static func resolvedUserAlias(from data: [String: Any]) -> String? {
        trimmedString(data["alias"] as? String)
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
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            dateFormatter.locale = Locale.current
            let addedDateText = dateFormatter.string(from: addedDate)
            
            await MainActor.run {
                friendInfo = FriendDetailInfo(
                    id: friendId,
                    name: Self.resolvedUserDisplayName(from: userData),
                    alias: Self.resolvedUserAlias(from: userData),
                    email: Self.trimmedString(userData["email"] as? String),
                    photoUrl: userData["photo_url"] as? String ?? userData["photoUrl"] as? String,
                    region: Self.trimmedString(userData["region"] as? String),
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
    
    /// 大標題：顯示名優先，否則信箱
    var profileHeadline: String {
        if let n = name, !n.isEmpty { return n }
        if let e = email, !e.isEmpty { return e }
        return ""
    }
    
    /// 與主標題不同時才顯示的別名一行
    var distinctAliasLine: String? {
        guard let raw = alias, !raw.isEmpty else { return nil }
        let head = profileHeadline
        guard !head.isEmpty else { return nil }
        if raw.caseInsensitiveCompare(head) == .orderedSame { return nil }
        return raw
    }
    
    var hasNonEmptyEmail: Bool {
        guard let e = email else { return false }
        return !e.isEmpty
    }
    
    var hasPublicMetaRows: Bool {
        let reg = region?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !reg.isEmpty || hasNonEmptyEmail
    }
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
