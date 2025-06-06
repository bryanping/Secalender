import SwiftUI



struct EventEditView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @ObservedObject var viewModel: EventDetailViewModel
    var onComplete: (() -> Void)? = nil

    var body: some View {
        Form {
            Section {
                TextField("输入标题", text: $viewModel.event.title)

                DatePicker("日期", selection: $viewModel.event.date, displayedComponents: .date)

                DatePicker("开始时间", selection: $viewModel.event.startDate, displayedComponents: .hourAndMinute)

                DatePicker("结束时间", selection: $viewModel.event.endDate, displayedComponents: .hourAndMinute)

            } header: {
                Text("编辑活动")
            }
            
            Section {
                Toggle("公开给好友", isOn: $viewModel.event.openChecked)
            } header: {
                Text("分享")
            }

            Button("更新活动") {
                viewModel.saveEvent { success in
                    if success {
                        onComplete?()
                    } else {
                        // 更新失败逻辑
                    }
                }
            }
        }
        .navigationTitle("编辑活动")
        .onAppear {
            viewModel.loadEvent()
        }
    }
}


