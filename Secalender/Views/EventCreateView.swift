import SwiftUI
import Foundation
import MapKit

struct EventCreateView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL

    @ObservedObject var viewModel: EventDetailViewModel
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var syncToAppleCalendar = false
    @State private var selectedStartDate: Date = Date()
    @State private var selectedEndDate: Date = Date()
    @State private var selectedStartTime: Date = Date()
    @State private var selectedEndTime: Date = Date()
    @State private var showRepeatOptions = false
    @State private var showCalendarOptions = false
    @State private var showTravelTimeOptions = false

    var onComplete: (() -> Void)? = nil
    
    // 重複選項
    private let repeatOptions = [
        ("never", "永不"),
        ("daily", "每天"),
        ("weekly", "每週"),
        ("monthly", "每月"),
        ("yearly", "每年")
    ]
    
    // 行事曆組件選項
    private let calendarOptions = [
        ("default", "活動安排"),
        ("work", "工作"),
        ("personal", "個人"),
        ("family", "家庭"),
        ("study", "學習")
    ]
    
    // 路程時間選項
    private let travelTimeOptions = [
        ("無", nil),
        ("5 分鐘", "5"),
        ("15 分鐘", "15"),
        ("30 分鐘", "30"),
        ("1 小時", "60"),
        ("1.5 小時", "90"),
        ("2 小時", "120")
    ]

    var body: some View {
        NavigationView {
            Form {
                // 標題輸入
                Section {
                    HStack {
                        Text("標題")
                            .foregroundColor(.primary)
                        TextField("行程", text: $viewModel.event.title)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // 地點輸入
                Section {
                    HStack {
                        Text("地點")
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: {
                            openMapForLocationInput()
                        }) {
                            Text(viewModel.event.destination.isEmpty ? "選擇地點" : viewModel.event.destination)
                                .foregroundColor(viewModel.event.destination.isEmpty ? .gray : .primary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                
                // 整日活動開關（Bool? 修正）
                Section {
                    Toggle("整日", isOn: Binding(
                        get: { viewModel.event.isAllDay ?? false },
                        set: { viewModel.event.isAllDay = $0 }
                    ))
                    .onChange(of: viewModel.event.isAllDay ?? false) { isAllDay in
                        if isAllDay {
                            // 整日活動時設置為全天
                            let calendar = Calendar.current
                            selectedStartTime = calendar.startOfDay(for: selectedStartDate)
                            selectedEndTime = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: selectedStartDate)) ?? selectedStartDate
                        }
                    }
                }
                
                // 時間設置
                Section {
                    // 開始時間
                    HStack {
                        Text("開始")
                            .foregroundColor(.primary)
                        Spacer()
                        if viewModel.event.isAllDay ?? false {
                            DatePicker("", selection: $selectedStartDate, displayedComponents: .date)
                                .labelsHidden()
                        } else {
                            VStack(alignment: .trailing, spacing: 4) {
                                DatePicker("", selection: $selectedStartDate, displayedComponents: .date)
                                    .labelsHidden()
                                DatePicker("", selection: $selectedStartTime, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                            }
                        }
                    }
                    .onChange(of: selectedStartDate) { newValue in
                        viewModel.event.date = dateToString(newValue, format: "yyyy-MM-dd")
                        // 如果結束日期早於開始日期，自動調整結束日期
                        if selectedEndDate < newValue {
                            selectedEndDate = newValue
                            viewModel.event.endDate = dateToString(newValue, format: "yyyy-MM-dd")
                        }
                    }
                    .onChange(of: selectedStartTime) { newValue in
                        viewModel.event.startTime = dateToString(newValue, format: "HH:mm:ss")
                        // 自動調整結束時間為開始時間後一小時
                        if Calendar.current.isDate(selectedStartDate, inSameDayAs: selectedEndDate) {
                            let newEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
                            selectedEndTime = newEndTime
                            viewModel.event.endTime = dateToString(newEndTime, format: "HH:mm:ss")
                        }
                    }
                    
                    // 結束時間
                    if !(viewModel.event.isAllDay ?? false) {
                        HStack {
                            Text("結束")
                                .foregroundColor(.primary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                DatePicker("", selection: $selectedEndDate, displayedComponents: .date)
                                    .labelsHidden()
                                DatePicker("", selection: $selectedEndTime, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                            }
                        }
                        .onChange(of: selectedEndDate) { newValue in
                            viewModel.event.endDate = dateToString(newValue, format: "yyyy-MM-dd")
                        }
                        .onChange(of: selectedEndTime) { newValue in
                            viewModel.event.endTime = dateToString(newValue, format: "HH:mm:ss")
                        }
                    }
                }
                
                // 路程時間
                Section {
                    HStack {
                        Text("路程時間")
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: {
                            showTravelTimeOptions = true
                        }) {
                            Text(getTravelTimeDisplayText())
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 重複設置
                Section {
                    HStack {
                        Text("重複")
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: {
                            showRepeatOptions = true
                        }) {
                            Text(getRepeatDisplayText())
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 行事曆組件
                Section {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(getCalendarColor())
                        Text("行事曆")
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: {
                            showCalendarOptions = true
                        }) {
                            Text(getCalendarDisplayText())
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 邀請對象
                Section {
                    HStack {
                        Text("邀請對象")
                            .foregroundColor(.primary)
                        Spacer()
                        Button("無") {
                            // TODO: 實現邀請功能
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // 其他設置（Bool? 修正）
                Section {
                    Toggle("公開給好友", isOn: Binding(
                        get: { viewModel.event.isOpenChecked },
                        set: { viewModel.event.openChecked = $0 ? 1 : 0 }
                    ))
                    Toggle("同步到 Apple 日曆", isOn: $syncToAppleCalendar)
                }
            }
            .navigationTitle("新增")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        saveEvent()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("錯誤", isPresented: $showErrorAlert) {
            Button("好") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showRepeatOptions) {
            RepeatOptionsView(selectedRepeat: $viewModel.event.repeatType)
        }
        .sheet(isPresented: $showCalendarOptions) {
            CalendarOptionsView(selectedCalendar: $viewModel.event.calendarComponent)
        }
        .sheet(isPresented: $showTravelTimeOptions) {
            TravelTimeOptionsView(selectedTravelTime: $viewModel.event.travelTime)
        }
        .onAppear {
            initializeDatePickers()
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("LocationSelected"),
                object: nil,
                queue: .main
            ) { notification in
                if let address = notification.userInfo?["address"] as? String {
                    viewModel.event.destination = address
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(
                self,
                name: NSNotification.Name("LocationSelected"),
                object: nil
            )
        }
    }
    
    // MARK: - 私有方法
    
    private func initializeDatePickers() {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let nextHour = currentMinute > 0 ? currentHour + 1 : currentHour
        let roundedStartTime = calendar.date(bySettingHour: nextHour, minute: 0, second: 0, of: now) ?? now
        let roundedEndTime = calendar.date(byAdding: .hour, value: 1, to: roundedStartTime) ?? roundedStartTime
        
        if let dateObj = viewModel.event.dateObj {
            selectedStartDate = dateObj
        } else {
            selectedStartDate = now
        }
        
        if let endDateString = viewModel.event.endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            selectedEndDate = formatter.date(from: endDateString) ?? selectedStartDate
        } else {
            selectedEndDate = selectedStartDate
        }
        
        if let startDateTime = viewModel.event.startDateTime {
            selectedStartTime = startDateTime
        } else {
            selectedStartTime = roundedStartTime
            viewModel.event.startTime = dateToString(roundedStartTime, format: "HH:mm:ss")
        }
        
        if let endDateTime = viewModel.event.endDateTime {
            selectedEndTime = endDateTime
        } else {
            selectedEndTime = roundedEndTime
            viewModel.event.endTime = dateToString(roundedEndTime, format: "HH:mm:ss")
        }
        
        viewModel.event.date = dateToString(selectedStartDate, format: "yyyy-MM-dd")
        if !Calendar.current.isDate(selectedStartDate, inSameDayAs: selectedEndDate) {
            viewModel.event.endDate = dateToString(selectedEndDate, format: "yyyy-MM-dd")
        }
    }
    
    private func saveEvent() {
        if !(viewModel.event.isAllDay ?? false) {
            if (viewModel.event.startDateTime ?? Date()) >= (viewModel.event.endDateTime ?? Date()) {
                errorMessage = "開始時間必須早於結束時間"
                showErrorAlert = true
                return
            }
        }

        Task {
            do {
                try await viewModel.saveEvent(currentUserOpenId: userManager.userOpenId)
                if syncToAppleCalendar {
                    // TODO: 實現同步到 Apple 日曆
                }
                onComplete?()
                dismiss()
            } catch {
                errorMessage = "保存失敗：\(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func getRepeatDisplayText() -> String {
        return repeatOptions.first { $0.0 == viewModel.event.repeatType }?.1 ?? "永不"
    }
    
    private func getCalendarDisplayText() -> String {
        return calendarOptions.first { $0.0 == viewModel.event.calendarComponent }?.1 ?? "活動安排"
    }
    
    private func getTravelTimeDisplayText() -> String {
        if let travelTime = viewModel.event.travelTime {
            return travelTimeOptions.first { $0.1 == travelTime }?.0 ?? "無"
        }
        return "無"
    }
    
    private func getCalendarColor() -> Color {
        switch viewModel.event.calendarComponent {
        case "work": return .blue
        case "personal": return .green
        case "family": return .orange
        case "study": return .purple
        default: return .red
        }
    }
    
    private func openMapForLocationInput() {
        if isInChina() {
            if let url = URL(string: "iosamap://poi?sourceApplication=secalender&backScheme=secalender://location&keywords=地点") {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if let webUrl = URL(string: "https://uri.amap.com/search?query=地点&callnative=1&backurl=secalender://location") {
                    UIApplication.shared.open(webUrl)
                }
            }
        } else {
            if let googleMapsUrl = URL(string: "comgooglemaps://?q=location&callback=secalender://location") {
                if UIApplication.shared.canOpenURL(googleMapsUrl) {
                    UIApplication.shared.open(googleMapsUrl)
                } else {
                    let searchRequest = MKLocalSearch.Request()
                    searchRequest.naturalLanguageQuery = "地点"
                    let search = MKLocalSearch(request: searchRequest)
                    search.start { response, error in
                        if let response = response, let firstItem = response.mapItems.first {
                            firstItem.openInMaps(launchOptions: [
                                MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue,
                                MKLaunchOptionsShowsTrafficKey: false
                            ])
                        } else {
                            let mapItem = MKMapItem.forCurrentLocation()
                            mapItem.openInMaps(launchOptions: [MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue])
                        }
                    }
                }
            }
        }
    }
    
    private func isInChina() -> Bool {
        let timeZone = TimeZone.current
        return timeZone.identifier.contains("Asia/Shanghai") || timeZone.identifier.contains("Asia/Chongqing")
    }
    
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
}
