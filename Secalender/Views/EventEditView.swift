//
//  EventEditView.swift
//  Secalender
//
//  Created by linping on 2025/6/5.
//

import SwiftUI
import CoreLocation
import MapKit    // 修改内容：合併 EventShareView 的地圖導航能力
import Firebase  // 修改内容：參與人員查詢

/// 编辑来源类型
enum EditSource {
    case singleView    // 从单一行程检视页面进入
    case multiView     // 从多行程检视页面进入
    case calendar      // 从行事历直接进入
}

struct EventEditView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: EventDetailViewModel

    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var hasInitialized = false
    @State private var showLocationPicker = false

    // 使用本地状态保存用户输入，避免被外部更新覆盖
    @State private var title: String = ""
    @State private var destination: String = ""
    @State private var information: String = ""
    @State private var isOpenChecked: Bool = false
    @State private var isAllDay: Bool = false
    @State private var repeatType: String = "never"
    @State private var calendarComponent: String = "default"
    
    // Date/Time 本地状态
    @State private var selectedDate: Date = Date()
    @State private var selectedStartTime: Date = Date()
    @State private var selectedEndTime: Date = Date().addingTimeInterval(3600)
    @State private var selectedEndDate: Date = Date()
    
    @State private var isHasEnd: Bool = false //修改内容：作为 UI 意图层开关（唯一真相）
    
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    @State private var selectedTags: [String] = []

    // 修改内容：分享 / 邀請
    @State private var showInviteFriends = false

    // 修改内容：參與人員列表
    @State private var participants: [(userId: String, name: String, photoUrl: String?)] = []
    @State private var isLoadingParticipants = false

    // 修改内容：地圖應用選擇器
    @State private var showMapAppSelector = false
    @State private var mapAppSelectorDestination: String = ""
    @State private var mapAppSelectorCoordinate: CLLocationCoordinate2D?
    @State private var mapAppSelectorTransportType: MKDirectionsTransportType = .automobile

    // 修改内容：交通時間
    @State private var travelTimeInfo: (efficientTime: TimeInterval?, taxiTime: TimeInterval?, routeInfo: String?)?
    @State private var isCalculatingTravelTime = false
    @StateObject private var eventLocationManager = EventLocationManager()

    // 修改内容：加入日曆錯誤提示
    @State private var calendarError: String?

    let onComplete: (() -> Void)?
    let onDelete: (() -> Void)?  // 删除后的回调
    let source: EditSource  // 编辑来源

    // 显式初始化器
    init(
        viewModel: EventDetailViewModel,
        onComplete: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        source: EditSource = .singleView
    ) {
        self.viewModel = viewModel
        self.onComplete = onComplete
        self.onDelete = onDelete
        self.source = source
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 修改内容：Apple 同步 Step7 — 顯示行程來源（同步自哪個日曆）
                EventSourceBanner(event: viewModel.event)

                // 單一卡片包含所有字段：行程標題、活動內容、地點、時間
                EventFormCard(icon: "calendar", title: "行程資訊", iconColor: .blue) {
                    VStack(spacing: 16) {
                        // 行程標題
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("event_create.title".localized())
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(title.count)/20")
                                    .font(.system(size: 10))
                                    .foregroundColor(title.count >= 20 ? .red : .secondary)
                            }
                            
                            TextField("event_create.title_placeholder".localized(), text: Binding(
                                get: { title },
                                set: { newValue in
                                    // 限制最多20个字符
                                    if newValue.count <= 20 {
                                        title = newValue
                                    }
                                }
                            ))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemGray6))
                            )
                        }
                        
                        // 活動內容
                        VStack(alignment: .leading, spacing: 4) {
                            Text("event_create.content".localized())
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            GlassTextEditor(
                                placeholder: "event_create.content_placeholder".localized(),
                                text: $information,
                                minHeight: 80
                            )
                        }
                        
                        // 選擇地點
                        VStack(alignment: .leading, spacing: 4) {
                            Text("event_create.select_location".localized())
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            // 地点输入字段（可点击编辑）
                            HStack(spacing: 8) {  // 修改内容：地點欄 + 導航鈕
                                Button(action: {
                                    showLocationPicker = true
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 20))

                                        Text(destination.isEmpty ? "event_create.select_location".localized() : destination)
                                            .foregroundColor(destination.isEmpty ? .gray : .primary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .font(.caption)
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

                                // 修改内容：導航按鈕（移植自 EventShareView）
                                if !destination.isEmpty {
                                    Button(action: {
                                        showMapSelectorForNavigation(transportType: .automobile)
                                    }) {
                                        Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            // 修改内容：交通時間（移植自 EventShareView）
                            travelTimeSection
                        }
                        
                        // 事件標籤
                        VStack(alignment: .leading, spacing: 8) {
                            Text("event_tags.label".localized())
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(EventTagPresets.defaultTags, id: \.key) { tag in
                                        let key = tag.key
                                        let isSelected = selectedTags.contains(key)
                                        Button {
                                            if isSelected {
                                                selectedTags.removeAll { $0 == key }
                                            } else {
                                                selectedTags.append(key)
                                            }
                                        } label: {
                                            Text(tag.localizedKey.localized())
                                                .font(.system(size: 13))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(isSelected ? Color.blue : Color(UIColor.systemGray5))
                                                )
                                                .foregroundColor(isSelected ? .white : .primary)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        
                        // 設定時間
                        VStack(alignment: .leading, spacing: 4) {
                            Text("event_create.set_time".localized())
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            DateTimePickerView(
                    startDate: $selectedDate,
                    startTime: $selectedStartTime,
                    endDate: Binding(
                        get: { isHasEnd ? selectedEndDate : nil },
                        set: { if let date = $0 { selectedEndDate = date } }
                    ),
                    endTime: Binding(
                        get: { isHasEnd ? selectedEndTime : nil },
                        set: { if let time = $0 { selectedEndTime = time } }
                    ),
                    isAllDay: $isAllDay,
                    isHasEnd: $isHasEnd
                )
                        }
                    }
                }
                // 修改内容：Phase 1-D — 移除重複掛載的 onChange(of: isAllDay)。
                // 此處無條件 isHasEnd=false 與下方較完整的版本衝突，
                // 導致編輯多日事件切整日時結束日期被清除。保留下方版本。
                
                // 修改内容：參與人員（移植自 EventShareView）
                participantsSection

                // 其他设置卡片
                EventSettingsCard(
                    isOpenChecked: $isOpenChecked,
                    repeatType: $repeatType,
                    calendarComponent: $calendarComponent
                )
            }
            .padding(.bottom, 80) // 为底部按钮留出空间
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .background(Color(.systemGroupedBackground))
        // 修改内容：底部固定操作列（更新 / 刪除）
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        hideKeyboard()
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        hideKeyboard()
                        updateEvent()
                    } label: {
                        Label("event_edit.update".localized(), systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(.systemBackground))

                Spacer().frame(height: 60)
            }
        }
        // 修改内容：載入參與人員
        .task {
            await loadParticipants()
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            
            // 初始化本地状态
            title = viewModel.event.title
            destination = viewModel.event.destination
            information = viewModel.event.information ?? ""
            isOpenChecked = viewModel.event.openChecked == 1
            isAllDay = viewModel.event.isAllDay ?? false
            repeatType = viewModel.event.repeatType ?? "never"
            calendarComponent = viewModel.event.calendarComponent ?? "default"
            selectedTags = viewModel.event.tags ?? []
            
            // 初始化日期
            if let dateObj = viewModel.event.dateObj {
                selectedDate = dateObj
            } else {
                selectedDate = Date()
            }
            
            // 初始化开始时间
            if let startDateTime = viewModel.event.startDateTime {
                selectedStartTime = startDateTime
            } else {
                selectedStartTime = Date()
            }
            
            // 初始化结束日期（若没存就等于开始日期）
            if let endDateString = viewModel.event.endDate,
               let endDateObj = stringToDate(endDateString, format: "yyyy-MM-dd") {
                selectedEndDate = endDateObj
            } else {
                selectedEndDate = selectedDate
            }
            
            // 初始化结束时间（若没存就给一个“备用值”，但 UI 是否显示由 isHasEnd 决定）
            if let endDateTime = viewModel.event.endDateTime {
                selectedEndTime = endDateTime
            } else {
                selectedEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: selectedStartTime) ?? Date().addingTimeInterval(3600) //修改内容
            }
            
            //修改内容：isHasEnd 初始化只看“是否真的有结束字段”，不做推断
            if !isAllDay {
                isHasEnd = viewModel.event.endDate != nil
            } else {
                isHasEnd = viewModel.event.endDate != nil && viewModel.event.endDate != viewModel.event.date
            }
        }
        .onChange(of: isAllDay) { _, newValue in
            if newValue {
                let calendar = Calendar.current
                selectedStartTime = calendar.startOfDay(for: selectedDate)
                selectedEndTime = calendar.date(byAdding: .hour, value: 1, to: selectedStartTime) ?? selectedStartTime
                if viewModel.event.endDate == nil || viewModel.event.endDate == viewModel.event.date {
                    isHasEnd = false
                    selectedEndDate = selectedDate
                }
            }
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("好") {}
        } message: {
            Text(errorMessage)
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let eventId = viewModel.event.id {
                    // 立即更新本地缓存（不等待网络）
                    EventManager.shared.softDeleteEvent(eventId: eventId)
                    
                    // 立即调用删除回调（如果存在）
                    onDelete?()
                    
                    // 如果没有删除回调，调用完成回调
                    if onDelete == nil {
                        onComplete?()
                    }
                    
                    // 立即关闭页面（不等待网络请求）
                    dismiss()
                }
            }
        } message: {
            Text("event_edit.delete_confirmation".localized())
        }
        .navigationTitle("event_edit.title".localized())
        .navigationBarTitleDisplayMode(.large)
        // 修改内容：分享按鈕移至右上角
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showInviteFriends = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                selectedAddress: $destination,
                selectedCoordinate: $selectedCoordinate
            )
        }
        // 修改内容：邀請好友（分享）
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsView(event: viewModel.event)
                .environmentObject(userManager)
        }
        // 修改内容：地圖應用選擇器
        .sheet(isPresented: $showMapAppSelector) {
            MapAppSelectorView(
                destination: mapAppSelectorDestination,
                coordinate: mapAppSelectorCoordinate,
                transportType: mapAppSelectorTransportType
            )
        }
        // 修改内容：加入日曆錯誤提示
        .alert("event_share.cannot_add_to_calendar".localized(), isPresented: Binding(get: {
            calendarError != nil
        }, set: { newValue in
            if !newValue { calendarError = nil }
        })) {
            Button("settings.ok".localized()) {}
        } message: {
            Text(calendarError ?? "event_share.unknown_error".localized())
        }
    }

    // MARK: - 參與人員（移植自 EventShareView）

    @ViewBuilder
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("event_share.shared_with".localized())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: -8) {
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

                Spacer()

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

    /// 加载参与人员列表（移植自 EventShareView）
    private func loadParticipants() async {
        guard let eventId = viewModel.event.id else { return }

        isLoadingParticipants = true
        defer { isLoadingParticipants = false }

        do {
            // 从 event_shares 集合中获取状态为 "joined" 的用户
            let db = Firestore.firestore()
            let snapshot = try await db.collection("event_shares")
                .whereField("eventId", isEqualTo: eventId)
                .whereField("status", isEqualTo: "joined")
                .getDocuments()

            var loadedParticipants: [(userId: String, name: String, photoUrl: String?)] = []

            for doc in snapshot.documents {
                let data = doc.data()
                guard let userId = data["receiverId"] as? String else { continue }

                let userDoc = try? await db.collection("users")
                    .whereField("openid", isEqualTo: userId)
                    .limit(to: 1)
                    .getDocuments()

                if let userData = userDoc?.documents.first?.data() {
                    let name = (userData["name"] as? String) ?? (userData["displayName"] as? String) ?? (userData["display_name"] as? String) ?? "event_share.unknown_user".localized()
                    let photoUrl = (userData["photo_url"] as? String) ?? (userData["photoUrl"] as? String)
                    loadedParticipants.append((userId: userId, name: name, photoUrl: photoUrl))
                } else {
                    loadedParticipants.append((userId: userId, name: "event_share.unknown_user".localized(), photoUrl: nil))
                }
            }

            await MainActor.run {
                participants = loadedParticipants
            }
        } catch {
            print("event_share.load_participants_failed".localized() + ": \(error.localizedDescription)")
        }
    }

    // MARK: - 交通時間與導航（移植自 EventShareView）

    @ViewBuilder
    private var travelTimeSection: some View {
        if destination.isEmpty {
            EmptyView()
        } else if let travelInfo = travelTimeInfo {
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

    /// 取得目的地座標
    private func getDestinationCoordinate() -> CLLocationCoordinate2D? {
        return selectedCoordinate
    }

    /// 顯示地圖選擇器進行導航
    private func showMapSelectorForNavigation(transportType: MKDirectionsTransportType) {
        mapAppSelectorDestination = destination
        mapAppSelectorCoordinate = getDestinationCoordinate()
        mapAppSelectorTransportType = transportType
        showMapAppSelector = true
    }

    /// 計算交通時間
    private func calculateTravelTime() {
        guard let currentLocation = eventLocationManager.currentLocation,
              !destination.isEmpty else { return }

        let geocodingFailedText = "event_share.geocoding_failed".localized()
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(destination) { placemarks, error in
            if let error = error {
                print(geocodingFailedText + ": \(error.localizedDescription)")
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

    // MARK: - 私有方法

    private func updateEvent() {
        viewModel.event.title = title
        viewModel.event.destination = destination
        viewModel.event.information = information.isEmpty ? nil : information
        viewModel.event.openChecked = isOpenChecked ? 1 : 0
        viewModel.event.isAllDay = isAllDay
        viewModel.event.repeatType = repeatType
        viewModel.event.calendarComponent = calendarComponent
        viewModel.event.tags = selectedTags.isEmpty ? nil : selectedTags
        
        // 日期
        viewModel.event.date = dateToString(selectedDate, format: "yyyy-MM-dd")
        
        if !isAllDay {
            // 开始时间
            viewModel.event.startTime = dateToString(selectedStartTime, format: "HH:mm:ss")
            
            //修改内容：结束字段完全由 isHasEnd 决定
            if isHasEnd {
                viewModel.event.endTime = dateToString(selectedEndTime, format: "HH:mm:ss")
                
                if selectedEndDate != selectedDate {
                    viewModel.event.endDate = dateToString(selectedEndDate, format: "yyyy-MM-dd")
                } else {
                    viewModel.event.endDate = nil
                }
            } else {
                // endTime 是 String 类型（非可选），不能为 nil，使用开始时间作为默认值
                viewModel.event.endTime = dateToString(selectedStartTime, format: "HH:mm:ss")
                viewModel.event.endDate = nil
            }
        } else {
            // 整日活动（你原逻辑保留）
            viewModel.event.startTime = "00:00:00"
            viewModel.event.endTime = "23:59:59"
            
            //修改内容：整日强制不写 endDate（避免被当成“结束区间”）
            if isHasEnd && selectedEndDate != selectedDate {
                viewModel.event.endDate = dateToString(selectedEndDate, format: "yyyy-MM-dd")
            } else {
                viewModel.event.endDate = nil
            }
        }
        
        // 先更新本地缓存（立即响应，不等待网络）
        let userId = userManager.userOpenId
        if viewModel.event.id != nil {
            // 更新事件：先更新本地缓存
            EventCacheManager.shared.updateEventInCache(viewModel.event, for: userId)
        } else {
            // 新建事件：先添加到本地缓存
            EventCacheManager.shared.addEventToCache(viewModel.event, for: userId)
        }
        
        // 立即调用完成回调和关闭页面（不等待网络）
        hideKeyboard()
        onComplete?()
        dismiss()
        
        // 后台异步更新 Firebase（不阻塞 UI）
        Task.detached {
            do {
                try await viewModel.saveEvent(currentUserOpenId: userId)
                // 修改内容：Phase 2-C — 重排本地提醒
                if let intId = viewModel.event.id {
                    EventReminderScheduler.shared.cancel(eventId: intId)
                }
                EventReminderScheduler.shared.schedule(for: viewModel.event)

                // 修改内容：Phase 2-E — 曾同步到 Apple 日曆的事件，編輯後回寫
                if let intId = viewModel.event.id,
                   let s = viewModel.event.startDateTime,
                   let e = viewModel.event.endDateTime {
                    AppleCalendarManager.shared.updateSyncedEvent(
                        eventId: intId,
                        title: viewModel.event.title,
                        start: s,
                        end: e,
                        location: viewModel.event.destination.isEmpty ? nil : viewModel.event.destination,
                        notes: viewModel.event.information
                    )
                }
            } catch {
                // 修改内容：Phase 1-C — 背景更新失敗改入同步佇列，自動重試
                print("⚠️ 后台更新 Firebase 失败，已加入同步佇列：\(error.localizedDescription)")
                var pending = viewModel.event
                if let intId = pending.id {
                    pending.syncStatus = .pendingUpdate
                    pending.updatedAtSync = Date()
                    EventCacheManager.shared.updateEventInCache(pending, for: userId)
                    SyncQueueService.shared.enqueue(SyncQueueItem(
                        entityType: .event,
                        entityId: String(intId),
                        actionType: .update,
                        lastError: error.localizedDescription,
                        userId: userId
                    ))
                }
            }
        }
    }
}

// 辅助方法
private func dateToString(_ date: Date, format: String) -> String {
    return DateFormatter.stable(format).string(from: date)  // 修改内容：Phase 1-A
}

private func stringToDate(_ string: String, format: String) -> Date? {
    return DateFormatter.stable(format).date(from: string)  // 修改内容：Phase 1-A
}

// 修改内容：依觀看者身份分流的行程入口
// 創建者 → EventEditView（可編輯，右上分享，底部更新/刪除）
// 非創建者 → EventShareView（唯讀 + 參與/不參與；社群管理者可從右上角進編輯）
struct EventDetailRoute: View {
    let event: Event
    var onEventUpdated: (() -> Void)? = nil

    @EnvironmentObject var userManager: FirebaseUserManager

    var body: some View {
        // 修改内容：整體行程 — 同批套用的行程視為一體，點選任一項回到整份行程編輯頁
        if event.creatorOpenid == userManager.userOpenId,
           let rid = event.planRequestId,
           let snap = AppliedPlanStore.shared.snapshot(requestId: rid, userId: userManager.userOpenId) {
            PlanDetailView(
                plan: snap.plan,
                customTitle: snap.title,
                onPlanUpdated: { _ in },
                onAddToCalendar: { onEventUpdated?() },
                initialRequestId: rid,
                initialTitle: snap.title
            )
            .environmentObject(userManager)
        } else if event.creatorOpenid == userManager.userOpenId {
            EventEditView(
                viewModel: EventDetailViewModel(event: event),
                onComplete: { onEventUpdated?() },
                onDelete: { onEventUpdated?() },
                source: .singleView
            )
            .environmentObject(userManager)
        } else {
            EventShareView(event: event, onEventUpdated: onEventUpdated)
                .environmentObject(userManager)
        }
    }
}

struct EventEditView_Previews: PreviewProvider {
    static var previews: some View {
        EventEditView(viewModel: EventDetailViewModel(event: Event(
            title: "测试活动",
            creatorOpenid: "test",
            color: "#FF6280",
            date: "2025-06-27",
            startTime: "09:00:00",
            endTime: "11:00:00",
            destination: "测试地点",
            mapObj: "",
            openChecked: 1,
            personChecked: 0,
            personNumber: nil,
            sponsorType: nil,
            category: nil,
            createTime: "2025-06-27 08:00:00",
            deleted: 0,
            information: nil
        )))
        .environmentObject(FirebaseUserManager.shared)
    }
}
