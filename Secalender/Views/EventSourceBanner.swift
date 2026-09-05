//
//  EventSourceBanner.swift
//  Secalender
//
//  修改内容：Apple 同步 Step7 — 編輯頁顯示行程來源（仿 Apple 日曆的「行事曆」欄位）
//

import SwiftUI

struct EventSourceBanner: View {
    let event: Event

    private var sourceName: String? { event.importSourceName }

    var body: some View {
        if let sourceName {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("同步自 \(sourceName)")
                        .font(.system(size: 14, weight: .medium))
                    Text("內容以來源日曆為準，重新同步時會覆蓋修改")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.08))
            )
            .padding(.horizontal, 16)
        }
    }
}
