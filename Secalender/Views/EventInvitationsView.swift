//
//  EventInvitationsView.swift
//  Secalender
//

import SwiftUI

struct EventInvitationsView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var invitations: [NotificationEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载邀请...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if invitations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("暂无活动邀请")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("好友邀请你参加的活动将显示在这里")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(invitations, id: \.id) { invitation in
                            InvitationRow(invitation: invitation) { status in
                                Task {
                                    await respondToInvitation(invitationId: invitation.id, status: status)
                                }
                            }
                        }
                    }
                    .refreshable {
                        await loadInvitations()
                    }
                }
                
                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("活动邀请")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await loadInvitations()
                }
            }
        }
    }
    
    private func loadInvitations() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allNotifications = try await EventManager.shared.fetchNotifications(for: userManager.userOpenId)
            let invitationNotifications = allNotifications.filter { $0.type == "event_invitation" }
            await MainActor.run {
                self.invitations = invitationNotifications
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "加载失败：\(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func respondToInvitation(invitationId: String, status: String) async {
        do {
            try await EventManager.shared.respondToInvitation(notificationId: invitationId, status: status)
            await MainActor.run {
                if let index = invitations.firstIndex(where: { $0.id == invitationId }) {
                    invitations[index] = NotificationEntry(
                        id: invitations[index].id,
                        eventId: invitations[index].eventId,
                        senderId: invitations[index].senderId,
                        receiverId: invitations[index].receiverId,
                        type: invitations[index].type,
                        createdAt: invitations[index].createdAt,
                        isRead: true,
                        status: status
                    )
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "响应失败：\(error.localizedDescription)"
            }
        }
    }
}

// 邀请行组件
struct InvitationRow: View {
    let invitation: NotificationEntry
    let onRespond: (String) -> Void
    
    @State private var event: Event?
    @State private var isLoadingEvent = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("邀请你参加活动")
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
                .background(Color.orange.opacity(0.1))
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
            
            if invitation.status == "pending" {
                HStack(spacing: 12) {
                    Button("拒绝") {
                        onRespond("declined")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    
                    Button("接受") {
                        onRespond("accepted")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
            }
            
            HStack {
                Text("\(invitation.createdAt)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if !invitation.isRead {
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
                let foundEvent = allEvents.first { $0.id == invitation.eventId }
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