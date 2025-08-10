
import SwiftUI

/// 顯示 AI 建議的行程清單
struct AIPlanResultView: View {
    @Binding var scheduleItems: [ScheduleItem]
    var onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if scheduleItems.isEmpty {
                    Text("沒有建議行程").padding()
                } else {
                    List {
                        ForEach(scheduleItems) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.headline)
                                Text("\(dateString(from: item.date)) \(timeString(from: item.startTime))–\(timeString(from: item.endTime))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(item.location).font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(item.description).font(.footnote)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }

                Button(action: {
                    onAdd()
                    dismiss()
                }) {
                    Text("添加到行程表")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding()
            }
            .navigationTitle("AI 建議行程")
        }
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
