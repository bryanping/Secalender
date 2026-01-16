//
//  CalendarOptionsView.swift
//  Secalender
//
//  Created by Assistant on 2024/7/27.
//

import SwiftUI
import EventKit

struct CalendarOptionsView: View {
    @Binding var selectedCalendar: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: FirebaseUserManager
    
    @State private var userCalendars: [UserCalendar] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Text("错误")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.secondary)
                        Button("重试") {
                            Task {
                                await loadCalendars()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if userCalendars.isEmpty {
                    VStack(spacing: 16) {
                        Text("暂无可用日历")
                            .foregroundColor(.secondary)
                        Text("请前往设置开启日历权限")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
            List {
                        ForEach(userCalendars) { calendar in
                    HStack {
                        Image(systemName: "circle.fill")
                                    .foregroundColor(calendar.color)
                                Text(calendar.title)
                        Spacer()
                                if selectedCalendar == calendar.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                                selectedCalendar = calendar.id
                        dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("行事曆")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadCalendars()
            }
        }
    }
    
    private func loadCalendars() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. 请求日历权限
            await AppleCalendarManager.shared.requestAccessIfNeeded { granted in
                if !granted {
                    Task { @MainActor in
                        self.errorMessage = "需要日历权限才能查看日历列表"
                        self.isLoading = false
                    }
                    return
                }
            }
            
            // 2. 从本地缓存加载
            let cachedCalendars = UserPreferencesManager.shared.loadUserCalendarsFromCache(for: userManager.userOpenId)
            
            if !cachedCalendars.isEmpty {
                await MainActor.run {
                    self.userCalendars = cachedCalendars
                    self.isLoading = false
                }
            }
            
            // 3. 从Apple日历获取真实日历列表
            let ekCalendars = AppleCalendarManager.shared.getUserCalendars()
            let calendars = AppleCalendarManager.shared.convertToUserCalendars(ekCalendars)
            
            // 4. 保存到本地和Firebase
            if !calendars.isEmpty {
                try await UserPreferencesManager.shared.saveUserCalendars(calendars, for: userManager.userOpenId)
                
                await MainActor.run {
                    self.userCalendars = calendars
                    self.isLoading = false
                }
            } else {
                // 如果没有日历，使用默认日历
                await MainActor.run {
                    if self.userCalendars.isEmpty {
                        self.userCalendars = [UserCalendar(id: "default", title: "活動安排", colorHex: "FF0000")]
                    }
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载日历失败：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

#Preview {
    CalendarOptionsView(selectedCalendar: .constant("default"))
        .environmentObject(FirebaseUserManager.shared)
}
