import SwiftUI

struct EventShareView: View {
    let event: Event

    var body: some View {
        Form {
            Section(header: Text("活动标题")) {
                Text(event.title)
            }
            Section(header: Text("开始时间")) {
                Text(formatDate(event.startDate))
            }
            Section(header: Text("结束时间")) {
                Text(formatDate(event.endDate))
            }
            Section(header: Text("地点")) {
                Text(event.destination.isEmpty ? "无" : event.destination)
            }
            Section(header: Text("公开状态")) {
                Text(event.openChecked ? "公开" : "私密")
            }
        }
        .navigationTitle("查看活动")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
