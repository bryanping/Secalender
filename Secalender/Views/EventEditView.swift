//
//  EventEditView.swift
//  Secalender
//
//  Created by linping on 2025/6/5.
//

import SwiftUI

struct EventEditView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: EventDetailViewModel

    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false

    // 新增本地状态用于 DatePicker
    @State private var selectedDate: Date = Date()
    @State private var selectedStartTime: Date = Date()
    @State private var selectedEndTime: Date = Date().addingTimeInterval(3600)

    var onComplete: (() -> Void)? = nil

    var body: some View {
        Form {
            Section(header: Text("基本信息")) {
                TextField("输入标题", text: $viewModel.event.title)
                DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                DatePicker("开始时间", selection: $selectedStartTime, displayedComponents: .hourAndMinute)
                DatePicker("结束时间", selection: $selectedEndTime, displayedComponents: .hourAndMinute)
                TextField("地点", text: $viewModel.event.destination)
                Toggle("公开给好友", isOn: Binding(
                    get: { viewModel.event.openChecked == 1 },
                    set: { viewModel.event.openChecked = $0 ? 1 : 0 }
                ))
            }

            Button("更新活动") {
                Task {
                    do {
                        try await viewModel.saveEvent(currentUserOpenId: userManager.userOpenId)
                        onComplete?()
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
            
            Button("删除活动", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .onAppear {
            // 初始化本地 DatePicker 状态
            selectedDate = stringToDate(viewModel.event.date, format: "yyyy-MM-dd") ?? Date()
            selectedStartTime = stringToDate(viewModel.event.startTime, format: "HH:mm:ss") ?? Date()
            selectedEndTime = stringToDate(viewModel.event.endTime, format: "HH:mm:ss") ?? Date().addingTimeInterval(3600)
        }
        .onChange(of: selectedDate) { newValue in
            viewModel.event.date = dateToString(newValue, format: "yyyy-MM-dd")
        }
        .onChange(of: selectedStartTime) { newValue in
            viewModel.event.startTime = dateToString(newValue, format: "HH:mm:ss")
        }
        .onChange(of: selectedEndTime) { newValue in
            viewModel.event.endTime = dateToString(newValue, format: "HH:mm:ss")
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
                            try await EventManager.shared.deleteEvent(eventId: eventId)
                            onComplete?()
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
