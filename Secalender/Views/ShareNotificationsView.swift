//
//  ShareNotificationsView.swift
//  Secalender
//

import SwiftUI

struct ShareNotificationsView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var notifications: [NotificationEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载分享通知...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无分享通知")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("你收到的活动分享将显示在这里")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notifications, id: \.id) { notification in
                            ShareNotificationRow(notification: notification)
                        }
                    }
                    .refreshable {
                        await loadNotifications()
                    }
                }
                
                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("分享通知")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await loadNotifications()
                }
            }
        }
    }
    
    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allNotifications = try await EventManager.shared.fetchNotifications(for: userManager.userOpenId)
            let shareNotifications = allNotifications.filter { $0.type == "event_shared" }
            await MainActor.run {
                self.notifications = shareNotifications
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载失败：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// 分享通知行组件
struct ShareNotificationRow: View {
    let notification: NotificationEntry
    
    @State private var event: Event?
    @State private var isLoadingEvent = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("你收到一个活动分享")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let event = event {
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text(event.date)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text(event.startTime)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if !event.destination.isEmpty {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.gray)
                                .font(.caption)
                            Text(event.destination)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if isLoadingEvent {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载活动信息...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            HStack {
                Text("\(notification.createdAt)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadEvent()
        }
    }
    
    private func loadEvent() {
        Task {
            do {
                let allEvents = try await EventManager.shared.fetchEvents()
                let foundEvent = allEvents.first { $0.id == notification.eventId }
                await MainActor.run {
                    self.event = foundEvent
                    self.isLoadingEvent = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingEvent = false
                }
            }
        }
    }
} 