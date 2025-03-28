import SwiftUI

struct EventShareView: View {
    let event: Event

    var body: some View {
        Form {
            Section {
                Text("标题: \(event.title)")
                Text("日期: \(event.date, formatter: dateFormatter)")
                Text("开始时间: \(event.startDate, formatter: timeFormatter)")
                Text("结束时间: \(event.endDate, formatter: timeFormatter)")
                // 若已移除参与人数，可删掉下面这行
                // Text("参与人数: \(event.participants)")
            } header: {
                Text("活动详情")
            }
            
        }
        .navigationTitle("查看活动")
    }
}

private let dateFormatter: DateFormatter = {    
    let formatter = DateFormatter()   
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

private let timeFormatter: DateFormatter = {    
    let formatter = DateFormatter()   
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}() 
