import SwiftUI

struct EventCreateView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: EventDetailViewModel
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var onComplete: (() -> Void)? = nil

    var body: some View {
        Form {
            Section(header: Text("基本信息")) {
                TextField("输入标题", text: $viewModel.event.title)
                DatePicker("日期", selection: $viewModel.event.date, displayedComponents: .date)
                DatePicker("开始时间", selection: $viewModel.event.startDate, displayedComponents: .hourAndMinute)
                DatePicker("结束时间", selection: $viewModel.event.endDate, displayedComponents: .hourAndMinute)
                Toggle("公开给好友", isOn: $viewModel.event.openChecked)
            }

            Button("保存活动") {
                viewModel.saveEvent(currentUserOpenId: userManager.userOpenId) { success in
                    if success {
                        onComplete?()
                        dismiss()
                    } else {
                        errorMessage = "保存失败"
                        showErrorAlert = true
                    }
                }
            }
        }
        .alert("错误", isPresented: $showErrorAlert) {
            Button("好") {}
        } message: {
            Text(errorMessage)
        }
        .navigationTitle("创建活动")
    }
}
