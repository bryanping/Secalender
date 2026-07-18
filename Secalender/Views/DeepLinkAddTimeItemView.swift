//
//  DeepLinkAddTimeItemView.swift
//  Secalender
//
//  修改内容：時事活動 — 網頁「加入 App」深鏈（secalender://addevent）的確認頁：
//  顯示活動內容 → 一鍵寫入 time_items(type=event)。
//

import SwiftUI

struct DeepLinkAddTimeItemView: View {
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let notes: String?
    let onClose: () -> Void

    @State private var isSaving = false
    @State private var saved = false
    @State private var errorMessage: String? = nil

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 HH:mm"
        let fe = DateFormatter()
        fe.dateFormat = "HH:mm"
        return "\(f.string(from: start)) – \(fe.string(from: end))"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: saved ? "checkmark.circle.fill" : "calendar.badge.plus")
                .font(.system(size: 44))
                .foregroundColor(saved ? .green : .blue)

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(timeText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let loc = location, !loc.isEmpty {
                    Text("📍 " + loc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let n = notes, !n.isEmpty {
                    Text(n)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            if saved {
                Button(action: onClose) {
                    Text("完成")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            } else {
                Button(action: save) {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text("加入我的時間表")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(isSaving)

                Button("取消", action: onClose)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let item = TimeItem(
                    type: .event,
                    title: title,
                    notes: [notes, location.map { "地點：\($0)" }].compactMap { $0 }.joined(separator: "\n").isEmpty ? nil : [notes, location.map { "地點：\($0)" }].compactMap { $0 }.joined(separator: "\n"),
                    startAt: start,
                    endAt: end,
                    hasStartAt: true,
                    themeKey: "public_event",
                    source: .imported,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                _ = try await TimeItemService.shared.upsert(item)
                await MainActor.run {
                    isSaving = false
                    saved = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
