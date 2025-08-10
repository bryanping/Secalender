//
//  AIPlannerView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//

import SwiftUI

struct AIPlannerView: View {
    @EnvironmentObject var userManager: FirebaseUserManager

    @State private var inputText: String = ""
    @State private var scheduleItems: [ScheduleItem] = []
    @State private var isLoading = false
    @State private var showResult = false

    // 改用 Bool 控制彈窗，errorMessage 使用 String（非 Optional）
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("輸入您的需求").font(.headline)
                TextEditor(text: $inputText)
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))

                Button(action: {
                    Task { await generatePlan() }
                }) {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("生成建議行程")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(isLoading || inputText.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("AI 智能規劃")
            .sheet(isPresented: $showResult) {
                AIPlanResultView(scheduleItems: $scheduleItems) {
                    saveToCalendar()
                }
                .environmentObject(userManager)
            }
            // 改為以 Bool 判斷彈窗顯示
            .alert(isPresented: $showErrorAlert) {
                Alert(title: Text("錯誤"), message: Text(errorMessage), dismissButton: .default(Text("好")))
            }
        }
    }

    private func generatePlan() async {
        guard !inputText.isEmpty else { return }
        isLoading = true
        do {
            let items = try await OpenAIManager.shared.generateSchedule(prompt: inputText)
            self.scheduleItems = items
            self.showResult = true
        } catch {
            // 捕捉錯誤後設定 errorMessage 與 showErrorAlert
            self.errorMessage = error.localizedDescription
            self.showErrorAlert = true
        }
        isLoading = false
    }

    private func saveToCalendar() {
        Task {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"  // Event 期望的時間字串格式

            for item in scheduleItems {
                // 組合日期與時間（Date -> String）
                let startDate = combine(date: item.date, time: item.startTime)
                let endDate = combine(date: item.date, time: item.endTime)

                let dateString = dateFormatter.string(from: item.date)
                let startString = timeFormatter.string(from: startDate)
                let endString = timeFormatter.string(from: endDate)

                // 建立符合 Event 結構（date, startTime 等為 String）:contentReference[oaicite:1]{index=1}
                var event = Event()
                event.title = item.title
                event.creatorOpenid = userManager.userOpenId
                event.color = "#4285F4"
                event.date = dateString
                event.startTime = startString
                event.endTime = endString
                event.endDate = dateString
                event.destination = item.location
                event.mapObj = ""
                event.openChecked = 0
                event.personChecked = 0
                event.createTime = ""
                event.information = item.description
                event.groupId = nil

                do {
                    try await EventManager.shared.addEvent(event: event)
                } catch {
                    print("添加事件失敗：\(error)")
                }
            }
        }
    }

    /// 組合日期與時間，回傳帶時間的 Date
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: calendar.component(.second, from: time),
            of: date
        ) ?? date
    }
}
