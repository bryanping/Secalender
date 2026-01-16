//
//  EventShareView.swift
//  Secalender
//

import SwiftUI
import Foundation
import Firebase
import CoreLocation
import MapKit

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
    
    var onEventUpdated: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 标题卡片
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "textformat")
                            .foregroundColor(.blue)
                            .font(.title)
                        Text(event.title)
                            .font(.title)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // 活動介紹卡片
                if let info = event.information, !info.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.purple)
                            Text("活動介紹")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        Divider()
                        
                        Text(info)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                
                // 基本信息卡片
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("时间信息")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    Divider()
                    
                    if event.isAllDay ?? false {
                        InfoRow(icon: "calendar", iconColor: .blue, title: "日期", value: event.date)
                        if let endDate = event.endDate, endDate != event.date {
                            InfoRow(icon: "calendar.badge.clock", iconColor: .blue, title: "結束日期", value: endDate)
                        }
                        Label("全天事件", systemImage: "sun.max.fill")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                    } else {
                        InfoRow(icon: "play.circle.fill", iconColor: .green, title: "開始", value: "\(event.date) \(event.startTime)")
                        if let endDate = event.endDate, endDate != event.date {
                            InfoRow(icon: "stop.circle.fill", iconColor: .red, title: "結束", value: "\(endDate) \(event.endTime)")
                        } else {
                            InfoRow(icon: "stop.circle.fill", iconColor: .red, title: "結束時間", value: event.endTime)
                        }
                    }
                    
                    // 重複設置
                    if (event.repeatType ?? "never") != "never" {
                        Divider()
                        InfoRow(icon: "repeat", iconColor: .orange, title: "重複", value: getRepeatDisplayText(event.repeatType ?? "never"))
                    }
                    
                    // 日曆組件
                    if let calendarComponent = event.calendarComponent, !calendarComponent.isEmpty {
                        Divider()
                        InfoRow(icon: "calendar.badge.plus", iconColor: .green, title: "日曆", value: getCalendarDisplayText(calendarComponent))
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // 地点信息卡片
                if !event.destination.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.red)
                            Text("地点信息")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        Divider()
                        
                        Button(action: {
                            openMapForDestination(event.destination)
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.destination)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    Text("点击查看地图")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 路程时间显示
                        if let travelInfo = travelTimeInfo {
                            Divider()
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
                                            if let coordinate = getDestinationCoordinate() {
                                                TravelTimeCalculator.shared.openMapNavigation(
                                                    destination: coordinate,
                                                    transportType: .walking
                                                )
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "figure.walk")
                                                Text("约 \(Int(efficientTime / 60)) 分钟")
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
                                            if let coordinate = getDestinationCoordinate() {
                                                TravelTimeCalculator.shared.openMapNavigation(
                                                    destination: coordinate,
                                                    transportType: .automobile
                                                )
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "car.fill")
                                                Text("约 \(Int(taxiTime / 60)) 分钟")
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
                        } else if isCalculatingTravelTime {
                            Divider()
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("计算路程时间...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if eventLocationManager.currentLocation != nil {
                            Divider()
                            Button(action: {
                                calculateTravelTime()
                            }) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.blue)
                                    Text("计算路程时间")
                                        .foregroundColor(.blue)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                
                
                
                // 邀請人員
                if let invitees = event.invitees, !invitees.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                            Text("邀請人員")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        Divider()
                        
                        Text(invitees.joined(separator: ", "))
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                
                // 分享和权限设置
                if event.creatorOpenid == userManager.userOpenId {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("分享")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showInviteFriends = true
                        }) {
                            HStack {
                                Text("分享活动")
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
                }
                
                // 权限设置
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                        Text("权限设置")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: event.isOpenChecked ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(event.isOpenChecked ? .green : .gray)
                        Text(event.isOpenChecked ? "公开给好友" : "仅自己可见")
                            .foregroundColor(event.isOpenChecked ? .green : .gray)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            .padding()
            .padding(.bottom, 80) // 为底部按钮留出空间
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            // 底部操作按钮栏（根据观看者身份显示不同按钮）
            if !isLoadingRole {
                VStack(spacing: 0) {
                    bottomActionButtons
                    // 为 TabBar 预留额外空间（TabBar 高度约 100）
                    Spacer()
                        .frame(height: 100)
                }
            }
        }
        .task {
            await loadViewerRole()
        }
        .navigationTitle("查看活动")
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
        .alert("无法添加到行事历", isPresented: Binding(get: {
            calendarError != nil
        }, set: { newValue in
            if !newValue {
                calendarError = nil
            }
        })) {
            Button("好") {}
        } message: {
            Text(calendarError ?? "未知错误")
        }
       
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
                    Label("分享", systemImage: "square.and.arrow.up")
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
                    Label("分享", systemImage: "square.and.arrow.up")
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
                    Text("无权限访问")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if !FriendManager.shared.isFriend(with: event.creatorOpenid) {
                        Button("添加创建者为好友") {
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
                    Label("参与", systemImage: "checkmark.circle.fill")
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
                    Label("参与", systemImage: "circle")
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
                    Label("不参与", systemImage: "xmark.circle.fill")
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
                    Label("不参与", systemImage: "circle")
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
            print("加载用户社群失败: \(error.localizedDescription)")
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
                print("获取社群详情失败: \(error.localizedDescription)")
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
                print("加载参与状态失败: \(error.localizedDescription)")
                participationStatus = nil // 默认未表态
            }
        }
        
        isLoadingRole = false
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
            print("更新参与状态失败: \(error.localizedDescription)")
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
    
    private func deleteEvent() async {
        guard let eventId = event.id else {
            print("事件ID不存在，无法删除")
            return
        }
        
        do {
            try await EventManager.shared.deleteEvent(eventId: eventId)
            await MainActor.run {
                onEventUpdated?()
                dismiss()
            }
        } catch {
            print("删除事件失败: \(error.localizedDescription)")
        }
    }
    
    // 輔助方法
    private func getRepeatDisplayText(_ repeatType: String) -> String {
        switch repeatType {
        case "daily": return "每天"
        case "weekly": return "每週"
        case "monthly": return "每月"
        case "yearly": return "每年"
        default: return "永不"
        }
    }
    
    private func getCalendarDisplayText(_ calendarComponent: String) -> String {
        switch calendarComponent {
        case "event": return "活動安排"
        case "work": return "工作"
        case "personal": return "個人"
        case "family": return "家庭"
        case "health": return "健康"
        case "study": return "學習"
        default: return "活動安排"
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
    
    private func calculateTravelTime() {
        guard let currentLocation = eventLocationManager.currentLocation else { return }
        
        // 从destination获取坐标（需要地理编码）
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(event.destination) { placemarks, error in
            if let error = error {
                print("地理编码失败: \(error.localizedDescription)")
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
        print("位置获取失败: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
