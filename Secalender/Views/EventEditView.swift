//
//  EventEditView.swift
//  Secalender
//
//  Created by linping on 2025/6/5.
//

import SwiftUI
import CoreLocation

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
                // 單一卡片包含所有字段：行程標題、活動內容、地點、時間
                EventFormCard(icon: "calendar", title: "行程資訊", iconColor: .blue) {
                    VStack(spacing: 16) {
                        // 行程標題
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("行程標題")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(title.count)/20")
                                    .font(.system(size: 10))
                                    .foregroundColor(title.count >= 20 ? .red : .secondary)
                            }
                            
                            TextField("例如:抵達東京成田機場", text: Binding(
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
                            Text("活動內容")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            GlassTextEditor(
                                placeholder: "輸入活動備註或細節...",
                                text: $information,
                                minHeight: 80
                            )
                        }
                        
                        // 選擇地點
                        VStack(alignment: .leading, spacing: 4) {
                            Text("選擇地點")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            // 地点输入字段（可点击编辑）
                            Button(action: {
                                showLocationPicker = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 20))
                                    
                                    Text(destination.isEmpty ? "選擇地點" : destination)
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
                        }
                        
                        // 設定時間
                        VStack(alignment: .leading, spacing: 4) {
                            Text("設定時間")
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
                .onChange(of: isAllDay) { newValue in
                    if newValue {
                        isHasEnd = false
                        let calendar = Calendar.current
                        selectedStartTime = calendar.startOfDay(for: selectedDate)
                        selectedEndDate = selectedDate
                        selectedEndTime = calendar.date(byAdding: .hour, value: 1, to: selectedStartTime) ?? selectedStartTime
                    }
                }
                
                // 其他设置卡片
                EventSettingsCard(
                    isOpenChecked: $isOpenChecked,
                    repeatType: $repeatType,
                    calendarComponent: $calendarComponent
                )
                
                // 操作按钮
                VStack(spacing: 16) {
                    EventActionButton(
                        title: "更新活动",
                        icon: "checkmark.circle.fill",
                        style: .primary
                    ) {
                        updateEvent()
                    }
                    
                    EventActionButton(
                        title: "删除活动",
                        icon: "trash.fill",
                        style: .destructive
                    ) {
                        showDeleteConfirmation = true
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 80) // 为底部按钮留出空间
        }
        .background(Color(.systemGroupedBackground))
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
                isHasEnd = (viewModel.event.endTime != nil) || (viewModel.event.endDate != nil)
            } else {
                isHasEnd = false
            }
        }
        .onChange(of: isAllDay) { newValue in
            if newValue {
                //修改内容：整日时与控制器逻辑保持一致 -> 强制关闭结束时间
                isHasEnd = false
                
                let calendar = Calendar.current
                selectedStartTime = calendar.startOfDay(for: selectedDate)
                selectedEndDate = selectedDate
                selectedEndTime = calendar.date(byAdding: .hour, value: 1, to: selectedStartTime) ?? selectedStartTime
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
                Task {
                    do {
                        if let eventId = viewModel.event.id {
                            // 使用软删除
                            try await EventManager.shared.softDeleteEvent(eventId: eventId)
                            // 调用删除回调（如果存在）
                            onDelete?()
                            // 如果没有删除回调，调用完成回调
                            if onDelete == nil {
                                onComplete?()
                            }
                            dismiss()
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
        } message: {
            Text("确定要删除这个活动吗？此操作无法撤销。")
        }
        .navigationTitle("编辑活动")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                selectedAddress: $destination,
                selectedCoordinate: $selectedCoordinate
            )
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
            viewModel.event.endDate = nil
        }
        
        // 先更新本地缓存（立即响应，不等待网络）
        let userId = userManager.userOpenId
        if let eventId = viewModel.event.id {
            // 更新事件：先更新本地缓存
            EventCacheManager.shared.updateEventInCache(viewModel.event, for: userId)
        } else {
            // 新建事件：先添加到本地缓存
            EventCacheManager.shared.addEventToCache(viewModel.event, for: userId)
        }
        
        // 立即调用完成回调和关闭页面（不等待网络）
        onComplete?()
        dismiss()
        
        // 后台异步更新 Firebase（不阻塞 UI）
        Task.detached {
            do {
                try await viewModel.saveEvent(currentUserOpenId: userId)
            } catch {
                // 后台更新失败，记录错误但不影响用户体验
                // 因为本地缓存已经更新，用户可以继续使用
                print("⚠️ 后台更新 Firebase 失败：\(error.localizedDescription)")
            }
        }
    }
}

// 辅助方法
private func dateToString(_ date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
}

private func stringToDate(_ string: String, format: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.date(from: string)
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
