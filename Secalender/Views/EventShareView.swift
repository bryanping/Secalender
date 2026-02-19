//
//  EventShareView.swift
//  Secalender
//

import SwiftUI
import Foundation
import Firebase
import CoreLocation
import MapKit
import EventKit

struct EventShareView: View {
    let event: Event
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showInviteFriends = false
    @State private var showEditEvent = false
    @State private var showDeleteConfirmation = false
    @State private var calendarError: String?
    @State private var travelTimeInfo: (efficientTime: TimeInterval?, taxiTime: TimeInterval?, routeInfo: String?)?
    @State private var isCalculatingTravelTime = false
    @StateObject private var eventLocationManager = EventLocationManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    
    // 观看者身份和参与状态
    @State private var viewerRole: EventViewerRole = .stranger
    @State private var participationStatus: String? = nil // "shared", "joined", "declined", nil
    @State private var isLoadingRole = true
    @State private var isUpdatingParticipation = false
    @State private var userGroupIds: Set<String> = []
    @State private var friendIds: Set<String> = []
    
    // 参与人员列表
    @State private var participants: [(userId: String, name: String, photoUrl: String?)] = []
    @State private var isLoadingParticipants = false
    
    // 地图应用选择器
    @State private var showMapAppSelector = false
    @State private var mapAppSelectorDestination: String = ""
    @State private var mapAppSelectorCoordinate: CLLocationCoordinate2D?
    @State private var mapAppSelectorTransportType: MKDirectionsTransportType = .automobile
    
    // 跨国检测
    @State private var isInternationalTrip: Bool = false
    @State private var destinationCountry: String?
    
    var onEventUpdated: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 單一卡片包含所有字段：行程標題、活動內容、地點、時間
                tripInfoCard
                participantsSection
                if event.creatorOpenid == userManager.userOpenId {
                    shareSection
                }
                permissionSection
            }
            .padding(.bottom, 60) // 为底部按钮留出空间
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            // 底部操作按钮栏（根据观看者身份显示不同按钮）
            if !isLoadingRole {
                VStack(spacing: 0) {
                    bottomActionButtons
                    // 为 TabBar 预留额外空间（TabBar 高度约 100）
                    Spacer()
                        .frame(height: 60)
                }
            }
        }
        .task {
            await loadViewerRole()
            await loadParticipants()
            // 检测是否是跨国行程
            checkIfInternationalTrip()
        }
        .onChange(of: participationStatus) { _, _ in
            // 当参与状态改变时，重新加载参与人员列表
            Task {
                await loadParticipants()
            }
        }
        .navigationTitle("event_share.view_event".localized())
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if event.creatorOpenid == userManager.userOpenId {
                    Button(action: {
                        showEditEvent = true
                    }) {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsView(event: event)
                .environmentObject(userManager)
        }
        .sheet(isPresented: $showMapAppSelector) {
            MapAppSelectorView(
                destination: mapAppSelectorDestination,
                coordinate: mapAppSelectorCoordinate
            )
        }
        .sheet(isPresented: $showEditEvent) {
            NavigationView {
                EventEditView(
                    viewModel: EventDetailViewModel(event: event),
                    onComplete: {
                        // 更新后：刷新数据并保持在 EventShareView（不关闭 sheet）
                        showEditEvent = false
                        onEventUpdated?()
                        // 不调用 dismiss()，保持在 EventShareView
                    },
                    onDelete: {
                        // 删除后：返回行事历（关闭 sheet 并 dismiss）
                        showEditEvent = false
                        onEventUpdated?()
                        dismiss()  // 返回行事历
                    },
                    source: .singleView
                )
                .environmentObject(userManager)
            }
        }
        .alert("event_share.cannot_add_to_calendar".localized(), isPresented: Binding(get: {
            calendarError != nil
        }, set: { newValue in
            if !newValue {
                calendarError = nil
            }
        })) {
            Button("settings.ok".localized()) {}
        } message: {
            Text(calendarError ?? "event_share.unknown_error".localized())
        }
       
    }
    
    // MARK: - 子视图组件
    
    @ViewBuilder
    private var tripInfoCard: some View {
        EventFormCard(icon: "calendar", title: "event_share.trip_info".localized(), iconColor: .blue) {
            VStack(spacing: 16) {
                titleSection
                if let info = event.information, !info.isEmpty {
                    contentSection(info: info)
                }
                if !event.destination.isEmpty {
                    locationSection
                }
                timeSection
            }
        }
    }
    
    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("event_share.title".localized())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Text(event.title)
                .font(.system(size: 17))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                )
        }
    }
    
    @ViewBuilder
    private func contentSection(info: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("event_share.content".localized())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Text(info)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(minHeight: 80)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                )
        }
    }
    
    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("event_share.select_location".localized())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            Button(action: {
                showMapAppSelector = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    
                    Text(event.destination.formattedForDisplay)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            travelTimeSection
        }
    }
    
    @ViewBuilder
    private var travelTimeSection: some View {
        if let travelInfo = travelTimeInfo {
            VStack(alignment: .leading, spacing: 8) {
                if let routeInfo = travelInfo.routeInfo {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(routeInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 12) {
                    if let efficientTime = travelInfo.efficientTime {
                        Button(action: {
                            showMapSelectorForNavigation(transportType: .walking)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.walk")
                                Text("event_share.estimated_time".localized(with: Int(efficientTime / 60)))
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                    
                    if let taxiTime = travelInfo.taxiTime {
                        Button(action: {
                            showMapSelectorForNavigation(transportType: .automobile)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "car.fill")
                                Text("event_share.estimated_time".localized(with: Int(taxiTime / 60)))
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } else if isCalculatingTravelTime {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("event_share.calculating".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        } else if eventLocationManager.currentLocation != nil {
            Button(action: {
                calculateTravelTime()
            }) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("event_share.calculate".localized())
                        .foregroundColor(.blue)
                }
                .font(.subheadline)
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("event_share.set_time".localized())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            EventTimeDisplayView(event: event)
        }
    }
    
    @ViewBuilder
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("event_share.shared_with".localized())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            HStack(spacing: -8) {
                // 参与人员头像
                ForEach(participants.prefix(3), id: \.userId) { participant in
                    AsyncImage(url: participant.photoUrl.map { URL(string: $0) } ?? nil) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                }
                
                // 如果有更多参与者或可以添加，显示添加按钮
                if participants.count < 3 || (event.creatorOpenid == userManager.userOpenId || viewerRole == .groupAdminOrOwner) {
                    Button(action: {
                        showInviteFriends = true
                    }) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                Spacer()
                
                // 参与者数量
                Text("event_share.participants_count".localized(with: participants.count))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
                Text("event_share.share".localized())
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            Button(action: {
                showInviteFriends = true
            }) {
                HStack {
                    Text("event_share.share_event".localized())
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
                Text("event_share.permission_settings".localized())
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Divider()
            
            HStack {
                Image(systemName: event.isOpenChecked ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(event.isOpenChecked ? .green : .gray)
                Text(event.isOpenChecked ? "event_share.public_to_friends".localized() : "event_share.private_only".localized())
                    .foregroundColor(event.isOpenChecked ? .green : .gray)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // MARK: - 底部操作按钮栏
    
    @ViewBuilder
    private var bottomActionButtons: some View {
        HStack(spacing: 12) {
            switch viewerRole {
            case .creator:
                // 创建者：分享按钮
                Button {
                    showInviteFriends = true
                } label: {
                    Label("event_share.share".localized(), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                
            case .groupAdminOrOwner:
                // 社群管理者：删除、编辑、分享
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                
                Button {
                    showEditEvent = true
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                
                Button {
                    showInviteFriends = true
                } label: {
                    Label("event_share.share".localized(), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                
            case .sharedRecipient, .groupMember, .friend:
                // 被分享者/社群成员/好友：参与/不参与按钮
                participationButtons
                
            case .stranger:
                // 陌生人：显示无权限提示
                VStack(spacing: 8) {
                    Text("event_share.no_permission".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if !FriendManager.shared.isFriend(with: event.creatorOpenid) {
                        Button("event.add_friend".localized()) {
                            // TODO: 实现添加好友功能
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - 参与按钮
    
    @ViewBuilder
    private var participationButtons: some View {
        let isJoined = participationStatus == "joined"
        let isDeclined = participationStatus == "declined"
        
        // 参与按钮
        Group {
            if isJoined {
                Button {
                    Task {
                        await updateParticipationStatus("joined")
                    }
                } label: {
                    Label("event_share.participate".localized(), systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdatingParticipation)
            } else {
                Button {
                    Task {
                        await updateParticipationStatus("joined")
                    }
                } label: {
                    Label("event_share.participate".localized(), systemImage: "circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
        
                .disabled(isUpdatingParticipation)
            }
        }
        
        // 不参与按钮
        Group {
            if isDeclined {
                Button {
                    Task {
                        await updateParticipationStatus("declined")
                    }
                } label: {
                    Label("event_share.not_participate".localized(), systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdatingParticipation)
            } else {
                Button {
                    Task {
                        await updateParticipationStatus("declined")
                    }
                } label: {
                    Label("event_share.not_participate".localized(), systemImage: "circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
              
                .disabled(isUpdatingParticipation)
            }
        }
    }
    

    
    // MARK: - 身份判断和参与状态加载
    
    private func loadViewerRole() async {
        isLoadingRole = true
        
        // 加载用户社群列表
        do {
            let userGroups = try await GroupManager.shared.getUserGroups(userId: userManager.userOpenId)
            userGroupIds = Set(userGroups.compactMap { $0.id })
        } catch {
            print("event_share.load_groups_failed".localized() + ": \(error.localizedDescription)")
        }
        
        // 加载好友列表
        await FriendManager.shared.loadFriends(for: userManager.userOpenId)
        friendIds = Set() // 好友ID已缓存在 FriendManager 中
        
        // 判断是否为社群成员
        let isGroupMember: (String?) -> Bool = { groupId in
            guard let groupId = groupId else { return false }
            return self.userGroupIds.contains(groupId)
        }
        
        // 判断是否为社群管理员或拥有者（需要异步获取社群详情）
        var groupAdminOrOwnerIds: Set<String> = []
        for groupId in userGroupIds {
            do {
                let group = try await GroupManager.shared.getGroup(groupId: groupId)
                if group.isAdmin(userId: userManager.userOpenId) || group.isOwner(userId: userManager.userOpenId) {
                    groupAdminOrOwnerIds.insert(groupId)
                }
            } catch {
                print("event_share.get_group_details_failed".localized() + ": \(error.localizedDescription)")
            }
        }
        
        let isGroupAdminOrOwner: (String?) -> Bool = { groupId in
            guard let groupId = groupId else { return false }
            return groupAdminOrOwnerIds.contains(groupId)
        }
        
        // 判断是否为被分享者
        let isSharedRecipient: (Int, String) async -> Bool = { eventId, userId in
            do {
                let status = try await EventManager.shared.getParticipationStatus(
                    eventId: eventId,
                    userId: userId
                )
                return status != nil // 有记录就是被分享者
            } catch {
                return false
            }
        }
        
        // 判断观看者身份
        viewerRole = await EventAccessManager.shared.determineViewerRole(
            event: event,
            currentUserId: userManager.userOpenId,
            isFriend: { userId in
                FriendManager.shared.isFriend(with: userId)
            },
            isGroupMember: isGroupMember,
            isGroupAdminOrOwner: isGroupAdminOrOwner,
            isSharedRecipient: isSharedRecipient
        )
        
        // 加载参与状态
        if let eventId = event.id {
            do {
                participationStatus = try await EventManager.shared.getParticipationStatus(
                    eventId: eventId,
                    userId: userManager.userOpenId
                )
            } catch {
                print("event_share.load_participation_status_failed".localized() + ": \(error.localizedDescription)")
                participationStatus = nil // 默认未表态
            }
        }
        
        isLoadingRole = false
    }
    
    // MARK: - 加载参与人员列表
    
    private func loadParticipants() async {
        guard let eventId = event.id else { return }
        
        isLoadingParticipants = true
        
        do {
            // 从 event_shares 集合中获取状态为 "joined" 的用户
            let db = Firestore.firestore()
            let snapshot = try await db.collection("event_shares")
                .whereField("eventId", isEqualTo: eventId)
                .whereField("status", isEqualTo: "joined")
                .getDocuments()
            
            var loadedParticipants: [(userId: String, name: String, photoUrl: String?)] = []
            
            // 获取每个用户的信息
            for doc in snapshot.documents {
                let data = doc.data()
                guard let userId = data["receiverId"] as? String else { continue }
                
                // 从 users 集合获取用户信息
                let userDoc = try? await db.collection("users")
                    .whereField("openid", isEqualTo: userId)
                    .limit(to: 1)
                    .getDocuments()
                
                if let userData = userDoc?.documents.first?.data() {
                    // 优先使用 name 字段，兼容 displayName 和 display_name
                    let name = (userData["name"] as? String) ?? (userData["displayName"] as? String) ?? (userData["display_name"] as? String) ?? "event_share.unknown_user".localized()
                    let photoUrl = (userData["photo_url"] as? String) ?? (userData["photoUrl"] as? String)
                    loadedParticipants.append((userId: userId, name: name, photoUrl: photoUrl))
                } else {
                    // 如果找不到用户信息，使用默认值
                    loadedParticipants.append((userId: userId, name: "event_share.unknown_user".localized(), photoUrl: nil))
                }
            }
            
            await MainActor.run {
                self.participants = loadedParticipants
                self.isLoadingParticipants = false
            }
        } catch {
            print("event_share.load_participants_failed".localized() + ": \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingParticipants = false
            }
        }
    }
    
    // MARK: - 参与状态更新
    
    private func updateParticipationStatus(_ status: String) async {
        guard let eventId = event.id else { return }
        
        isUpdatingParticipation = true
        
        do {
            try await EventManager.shared.upsertParticipationStatus(
                eventId: eventId,
                userId: userManager.userOpenId,
                status: status,
                creatorId: event.creatorOpenid,
                source: determineParticipationSource()
            )
            
            // 更新本地状态
            participationStatus = status
            onEventUpdated?()
        } catch {
            print("event_share.update_participation_status_failed".localized() + ": \(error.localizedDescription)")
        }
        
        isUpdatingParticipation = false
    }
    
    /// 确定参与来源
    private func determineParticipationSource() -> String {
        if let groupId = event.groupId, userGroupIds.contains(groupId) {
            return "group"
        }
        if FriendManager.shared.isFriend(with: event.creatorOpenid) {
            return "friend"
        }
        if participationStatus != nil {
            return "direct"
        }
        return "link"
    }
    
    // MARK: - 删除事件
    
    /// 删除事件（立即更新本地缓存，Firebase 更新在后台进行）
    private func deleteEvent() {
        guard let eventId = event.id else {
            print("event_share.event_id_missing".localized())
            return
        }
        
        // 立即更新本地缓存（不等待网络）
        EventManager.shared.softDeleteEvent(eventId: eventId)
        
        // 立即通知 UI 更新并关闭页面
        onEventUpdated?()
        dismiss()
    }
    
    // 輔助方法
    @MainActor
    private func getRepeatDisplayText(_ repeatType: String) -> String {
        switch repeatType {
        case "daily": return "event_create.repeat_options.daily".localized()
        case "weekly": return "event_create.repeat_options.weekly".localized()
        case "monthly": return "event_create.repeat_options.monthly".localized()
        case "yearly": return "event_create.repeat_options.yearly".localized()
        default: return "event_create.repeat_options.never".localized()
        }
    }
    
    @MainActor
    private func getCalendarDisplayText(_ calendarComponent: String) -> String {
        // 优先从系统日历获取真实名称
        let userCalendars = UserPreferencesManager.shared.loadUserCalendarsFromCache(for: userManager.userOpenId)
        if let calendar = userCalendars.first(where: { $0.id == calendarComponent }) {
            return calendar.title
        }
        
        // 如果缓存中没有，尝试从系统获取
        let ekCalendars = AppleCalendarManager.shared.getUserCalendars()
        if let matchingCalendar = ekCalendars.first(where: { $0.calendarIdentifier == calendarComponent }) {
            return matchingCalendar.title
        }
        
        // 对于"default"或"event"，使用系统第一个日历的名称
        if calendarComponent == "default" || calendarComponent == "event" {
            if let firstCalendar = ekCalendars.first {
                return firstCalendar.title
            }
        }
        
        // 回退到本地化选项（仅限已知的类别）
        switch calendarComponent {
        case "work": return "event_create.calendar_options.work".localized()
        case "personal": return "event_create.calendar_options.personal".localized()
        case "family": return "event_create.calendar_options.family".localized()
        case "health": return "event_create.calendar_options.health".localized()
        case "study": return "event_create.calendar_options.study".localized()
        default: 
            // 对于default或其他未知值，尝试使用系统第一个日历，否则显示通用标签
            if let firstCalendar = ekCalendars.first {
                return firstCalendar.title
            }
            return "event_create.calendar".localized()
        }
    }
    
    private func openMapForDestination(_ destination: String) {
        let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        
        if isInChina() {
            let gaodeURL = "iosamap://path?sourceApplication=Secalender&dname=\(encodedDestination)"
            if let url = URL(string: gaodeURL) {
                openURL(url)
            } else if let webUrl = URL(string: "https://uri.amap.com/marker?position=\(encodedDestination)") {
                openURL(webUrl)
            }
        } else {
            let googleMapsURL = "comgooglemaps://?q=\(encodedDestination)"
            if let url = URL(string: googleMapsURL) {
                openURL(url)
            } else if let appleUrl = URL(string: "http://maps.apple.com/?q=\(encodedDestination)") {
                openURL(appleUrl)
            }
        }
    }
    
    private func isInChina() -> Bool {
        let timeZone = TimeZone.current
        let chinaTimeZones = ["Asia/Shanghai", "Asia/Chongqing", "Asia/Harbin", "Asia/Urumqi"]
        return chinaTimeZones.contains(timeZone.identifier)
    }
    
    private func getDestinationCoordinate() -> CLLocationCoordinate2D? {
        // 从mapObj或destination解析坐标
        // 这里简化处理，实际应该从mapObj JSON中解析
        // 暂时返回nil，让用户手动选择
        return nil
    }
    
    /// 显示地图选择器用于导航
    private func showMapSelectorForNavigation(transportType: MKDirectionsTransportType) {
        mapAppSelectorDestination = event.destination
        mapAppSelectorCoordinate = getDestinationCoordinate()
        mapAppSelectorTransportType = transportType
        showMapAppSelector = true
    }
    
    /// 检测是否是跨国行程
    private func checkIfInternationalTrip() {
        guard let userCountry = LocationCacheManager.shared.loadUserCountry() else {
            // 如果没有用户国家信息，尝试从当前定位获取
            if let currentLocation = eventLocationManager.currentLocation {
                reverseGeocodeForCountry(location: currentLocation) { userCountry in
                    if let userCountry = userCountry {
                        LocationCacheManager.shared.saveUserCountry(userCountry)
                        self.detectInternationalTrip(userCountry: userCountry)
                    }
                }
            }
            return
        }
        
        detectInternationalTrip(userCountry: userCountry)
    }
    
    /// 反向地理编码获取国家
    private func reverseGeocodeForCountry(location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first,
               let country = placemark.country {
                // 转换为中文国家名
                let dataManager = DestinationDataManager.shared
                let matchedCountries = dataManager.searchCountries(country)
                completion(matchedCountries.first)
            } else {
                completion(nil)
            }
        }
    }
    
    /// 检测跨国行程
    private func detectInternationalTrip(userCountry: String) {
        // 从目的地地址中提取国家信息
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(event.destination) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first,
                   let destCountry = placemark.country {
                    // 转换为中文国家名
                    let dataManager = DestinationDataManager.shared
                    let matchedCountries = dataManager.searchCountries(destCountry)
                    let destCountryChinese = matchedCountries.first ?? destCountry
                    
                    self.destinationCountry = destCountryChinese
                    
                    // 比较用户国家和目的地国家
                    let isInternational = userCountry != destCountryChinese
                    self.isInternationalTrip = isInternational
                    
                    #if DEBUG
                    print("🌍 跨国检测: 用户国家=\(userCountry), 目的地国家=\(destCountryChinese), 是否跨国=\(isInternational)")
                    #endif
                } else {
                    // 如果无法获取目的地国家，假设不是跨国
                    self.isInternationalTrip = false
                }
            }
        }
    }
    
    /// 打开机票选购（未来支持）
    private func openFlightBooking() {
        // TODO: 未来实现机票选购功能
        // 可以跳转到携程、去哪儿、飞猪等机票预订网站
        // 或者集成机票预订 API
        
        #if DEBUG
        print("✈️ 机票选购功能（未来支持）")
        print("目的地: \(event.destination)")
        if let country = destinationCountry {
            print("目的地国家: \(country)")
        }
        #endif
        
        // 临时：显示提示信息
        // 未来可以打开机票预订页面或集成第三方服务
    }
    
    /// 打开高铁选购（未来支持）
    private func openTrainBooking() {
        // TODO: 未来实现高铁票选购功能
        // 可以跳转到12306、携程等火车票预订网站
        // 或者集成火车票预订 API
        
        #if DEBUG
        print("🚄 高铁选购功能（未来支持）")
        print("目的地: \(event.destination)")
        #endif
        
        // 临时：显示提示信息
        // 未来可以打开火车票预订页面或集成第三方服务
    }
    
    private func calculateTravelTime() {
        guard let currentLocation = eventLocationManager.currentLocation else { return }
        
        // 先检测是否是跨国行程
        checkIfInternationalTrip()
        
        // 从destination获取坐标（需要地理编码）
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(event.destination) { placemarks, error in
            if let error = error {
                print("event_share.geocoding_failed".localized() + ": \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                return
            }
            
            self.isCalculatingTravelTime = true
            TravelTimeCalculator.shared.calculateTravelTime(
                from: currentLocation,
                to: location
            ) { efficientTime, taxiTime, routeInfo in
                DispatchQueue.main.async {
                    self.travelTimeInfo = (efficientTime, taxiTime, routeInfo)
                    self.isCalculatingTravelTime = false
                }
            }
        }
    }
}


// MARK: - 兼容 iOS 14 的按钮样式

/// 类型擦除的按钮样式包装器（用于解决三元运算符类型推断问题）
@available(iOS 15.0, *)
struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

/// 兼容 iOS 14 的边框按钮样式
struct PlainBorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - 事件位置管理器（用于EventShareView）
class EventLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let message = "event_share.location_fetch_failed".localized() + ": \(error.localizedDescription)"
            print(message)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
