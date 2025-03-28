import SwiftUI

struct EventCreateView: View {
    @ObservedObject var viewModel = EventDetailViewModel()
    var onComplete: (() -> Void)? = nil

    var body: some View {
        Form {
            Section {
                TextField("输入标题", text: $viewModel.event.title)

                DatePicker("日期", selection: $viewModel.event.date, displayedComponents: .date)

                DatePicker("开始时间", selection: $viewModel.event.startDate, displayedComponents: .hourAndMinute)

                DatePicker("结束时间", selection: $viewModel.event.endDate, displayedComponents: .hourAndMinute)

            } header: {
                Text("创建新活动")
            }
            
            Section {
                Toggle("公开给好友", isOn: $viewModel.event.openChecked)
            } header: {
                Text("分享")
            }

            Button("保存活动") {
                viewModel.saveEvent { success in
                    if success {
                        onComplete?()
                    } else {
                        // 处理保存失败
                    }
                }
            }
        }
        .navigationTitle("创建活动")
    }
}


struct EventCreateView_Previews: PreviewProvider {
    static var previews: some View {
        EventCreateView()
    }
}
