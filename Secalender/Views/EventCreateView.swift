import SwiftUI

struct EventCreateView: View {
    @ObservedObject var viewModel = EventDetailViewModel()

    var body: some View {
        Form {
            Section {
                TextField("输入标题", text: $viewModel.event.title)
                
                DatePicker("日期", selection: $viewModel.event.date, displayedComponents: .date)
                
                DatePicker("开始时间", selection: $viewModel.event.startDate, displayedComponents: .hourAndMinute)
                
                DatePicker("结束时间", selection: $viewModel.event.endDate, displayedComponents: .hourAndMinute)
                
              
            } header: { Text("创建新活动")
            }
            
            Button("保存活动") {
                viewModel.saveEvent { success in
                    if success {
                        // 处理保存成功
                    } else {
                        // 处理保存失败
                    }
                }
            }
        }
        .navigationTitle("创建活动")
    }
} 
