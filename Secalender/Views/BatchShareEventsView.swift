//
//  BatchShareEventsView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct BatchShareEventsView: View {
    let eventIds: [Int]
    let allEvents: [Event]
    var onComplete: (() -> Void)? = nil
    
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedFriends: [String] = []
    @State private var friends: [FriendEntry] = []
    @State private var isLoading = true
    @State private var isSharing = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    
    // 获取要分享的事件
    private var eventsToShare: [Event] {
        allEvents.filter { event in
            guard let eventId = event.id else { return false }
            return eventIds.contains(eventId)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 事件预览列表
            if !eventsToShare.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("batch_share.events_to_share".localized(with: eventsToShare.count))
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        ForEach(eventsToShare, id: \.id) { event in
                            EventPreviewRow(event: event)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .frame(maxHeight: 200)
                
                Divider()
            }
            
            // 好友选择列表
            if isLoading {
                ProgressView("加载好友列表...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if friends.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("batch_share.no_friends".localized())
                            .font(.headline)
                        Text("batch_share.add_friends_first".localized())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(friends, id: \.id) { friend in
                            FriendSelectionRow(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id),
                                onToggle: {
                                    if selectedFriends.contains(friend.id) {
                                        selectedFriends.removeAll { $0 == friend.id }
                                    } else {
                                        selectedFriends.append(friend.id)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            
            // 底部操作栏
            bottomActionBar
        }
        .navigationTitle("批量分享行程")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFriends()
        }
    }
    
    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            if let message = errorMessage {
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            if showSuccessMessage {
                Text("batch_share.success".localized())
                    .foregroundColor(.green)
                    .font(.caption)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 16) {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button {
                    Task {
                        await shareEvents()
                    }
                } label: {
                    if isSharing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("batch_share.share_to_friends".localized(with: selectedFriends.count))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFriends.isEmpty || isSharing)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private func loadFriends() {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            // 使用 FriendManager 的缓存机制（参考微信做法）
            let loadedFriends = await FriendManager.shared.getFriends(for: userManager.userOpenId)
            
            await MainActor.run {
                self.friends = loadedFriends
                self.isLoading = false
            }
        }
    }
    
    private func shareEvents() async {
        guard !selectedFriends.isEmpty && !eventIds.isEmpty else { return }
        
        await MainActor.run {
            isSharing = true
            errorMessage = nil
        }
        
        do {
            try await EventManager.shared.shareMultipleEventsWithFriends(
                eventIds: eventIds,
                friendIds: selectedFriends,
                senderId: userManager.userOpenId
            )
            
            await MainActor.run {
                isSharing = false
                showSuccessMessage = true
                
                // 延迟关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSuccessMessage = false
                    onComplete?()
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                isSharing = false
                errorMessage = "分享失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Event Preview Row

struct EventPreviewRow: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            // 时间
            if let start = event.startDateTime {
                Text(timeFormatter.string(from: start))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
            }
            
            // 标题
            Text(event.title)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            // 日期
            if let dateObj = event.dateObj {
                Text(dateFormatter.string(from: dateObj))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Formatters

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M月d日"
    return f
}()

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()
