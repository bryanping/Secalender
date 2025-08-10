//
//  EventShareView.swift
//  Secalender
//

import SwiftUI
import Foundation
import Firebase

struct EventShareView: View {
    let event: Event
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showInviteFriends = false
    @State private var showEditEvent = false
    @State private var calendarError: String?
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    
    var onEventUpdated: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(header: Text("标题: \(event.title)")) {
                    // 日期和時間顯示
                    if event.isAllDay ?? false {
                        Text("日期: \(event.date)")
                        if let endDate = event.endDate, endDate != event.date {
                            Text("結束日期: \(endDate)")
                        }
                        Text("全天事件")
                            .foregroundColor(.blue)
                    } else {
                        Text("開始: \(event.date) \(event.startTime)")
                        if let endDate = event.endDate, endDate != event.date {
                            Text("結束: \(endDate) \(event.endTime)")
                        } else {
                            Text("結束時間: \(event.endTime)")
                        }
                    }
                
                    // 重複設置
                    if (event.repeatType ?? "never") != "never" {
                        Text("重複: \(getRepeatDisplayText(event.repeatType ?? "never"))")
                            .foregroundColor(.orange)
                    }
                
                    // 日曆組件
                    if let calendarComponent = event.calendarComponent, !calendarComponent.isEmpty {
                                            Text("日曆: \(getCalendarDisplayText(calendarComponent))")
                            .foregroundColor(.green)
                    }

                    if !event.destination.isEmpty {
                        Button(action: {
                            openMapForDestination(event.destination)
                        }) {
                            HStack {
                                Image(systemName: "location")
                                Text("地点: \(event.destination)")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                        .foregroundColor(.blue)
                    }
                
                    // 邀請人員
                    if let invitees = event.invitees, !invitees.isEmpty {
                        Text("邀請人員: \(invitees.joined(separator: ", "))")
                            .foregroundColor(.blue)
                    }

                    if let info = event.information, !info.isEmpty {
                        Text("备注: \(info)")
                    }
                }
                
                if event.creatorOpenid == userManager.userOpenId {
                    Section {
                        Button {
                            showInviteFriends = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("分享活动")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                        .foregroundColor(.blue)
                    } header: {
                        Text("分享")
                    }
                }

                Section {
                    HStack {
                        Image(systemName: event.isOpenChecked ? "eye.fill" : "eye.slash.fill")
                                                Text(event.isOpenChecked ? "公开给好友" : "仅自己可见")
                    }
                    .foregroundColor(event.isOpenChecked ? .green : .gray)
                } header: {
                    Text("权限设置")
                }
            }

            Spacer()

            // 底部操作按钮栏
            HStack(spacing: 12) {
                Button {
                    showInviteFriends = true
                } label: {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("查看活动")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if event.creatorOpenid == userManager.userOpenId {
                    Button(action: {
                        showEditEvent = true
                    }) {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsView(event: event)
                .environmentObject(userManager)
        }
        .sheet(isPresented: $showEditEvent) {
            EventEditView(viewModel: EventDetailViewModel(event: event), onComplete: {
                showEditEvent = false
                onEventUpdated?()
                dismiss()
            })
            .environmentObject(userManager)
        }
        .alert("无法添加到行事历", isPresented: Binding(get: {
            calendarError != nil
        }, set: { newValue in
            if !newValue {
                calendarError = nil
            }
        })) {
            Button("好") {}
        } message: {
            Text(calendarError ?? "未知错误")
        }
    }
    
    // 輔助方法
    private func getRepeatDisplayText(_ repeatType: String) -> String {
        switch repeatType {
        case "daily": return "每天"
        case "weekly": return "每週"
        case "monthly": return "每月"
        case "yearly": return "每年"
        default: return "永不"
        }
    }
    
    private func getCalendarDisplayText(_ calendarComponent: String) -> String {
        switch calendarComponent {
        case "event": return "活動安排"
        case "work": return "工作"
        case "personal": return "個人"
        case "family": return "家庭"
        case "health": return "健康"
        case "study": return "學習"
        default: return "活動安排"
        }
    }
    
    private func openMapForDestination(_ destination: String) {
        let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        
        if isInChina() {
            let gaodeURL = "iosamap://path?sourceApplication=Secalender&dname=\(encodedDestination)"
            if let url = URL(string: gaodeURL) {
                openURL(url)
            } else if let webUrl = URL(string: "https://uri.amap.com/marker?position=\(encodedDestination)") {
                openURL(webUrl)
            }
        } else {
            let googleMapsURL = "comgooglemaps://?q=\(encodedDestination)"
            if let url = URL(string: googleMapsURL) {
                openURL(url)
            } else if let appleUrl = URL(string: "http://maps.apple.com/?q=\(encodedDestination)") {
                openURL(appleUrl)
            }
        }
    }
    
    private func isInChina() -> Bool {
        let timeZone = TimeZone.current
        let chinaTimeZones = ["Asia/Shanghai", "Asia/Chongqing", "Asia/Harbin", "Asia/Urumqi"]
        return chinaTimeZones.contains(timeZone.identifier)
    }
}
