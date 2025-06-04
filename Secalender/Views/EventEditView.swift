
//
//  EventEditView.swift
//  Secalender
//
//  Created by linping on 2025/6/5.
//
import SwiftUI
import Firebase

struct EventEditView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @StateObject var viewModel: EventDetailViewModel

    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingInviteView = false

    var body: some View {
        Form {
            DatePicker("开始时间", selection: $viewModel.event.startDate, displayedComponents: .hourAndMinute)
            DatePicker("结束时间", selection: $viewModel.event.endDate, displayedComponents: .hourAndMinute)
            TextField("地点", text: $viewModel.event.destination)
            Toggle("公开给好友", isOn: $viewModel.event.openChecked)

            Button("更新活动") {
                viewModel.saveEvent(currentUserOpenId: userManager.userOpenId) { success in
                    if success {
                        dismiss()
                    } else {
                        errorMessage = "更新失败，请稍后再试"
                        showErrorAlert = true
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingInviteView = true
                    } label: {
                        Label("邀请好友", systemImage: "person.crop.circle.badge.plus")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingInviteView) {
            InviteFriendView(selectedIds: $viewModel.event.sharedWithIds)
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("好") {}
        } message: {
            Text(errorMessage)
        }
        .navigationTitle("编辑活动")
    }
}
