//
//  EventShareActionView.swift
//  Secalender
//

import SwiftUI
import Firebase
import FirebaseFirestore
import UIKit

// 定义必要的视图组件
// 简化版ActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 不需要更新
    }
}

// 简化版FriendSelectionView
struct FriendSelectionView: View {
    @Binding var selectedFriends: [String]
    var onComplete: () -> Void
    
    var body: some View {
        Text("event_share_action.select_friends".localized())
            .onAppear {
                // 简化实现
                onComplete()
            }
    }
}

struct EventShareActionView: View {
    let event: Event // 使用导入的Event类型
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedFriends: [String] = []
    @State private var showFriendSelection = false
    @State private var showShareSheet = false
    @State private var shareText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 活动信息预览
                VStack(alignment: .leading, spacing: 12) {
                    Text("event_share_action.share_event".localized())
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "calendar")
                            Text(event.date)
                        }
                        .foregroundColor(.gray)
                        
                        HStack {
                            Image(systemName: "clock")
                            Text("\(event.startTime) - \(event.endTime)")
                        }
                        .foregroundColor(.gray)
                        
                        if !event.destination.isEmpty {
                            HStack {
                                Image(systemName: "location")
                                Text(event.destination)
                            }
                            .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // 分享选项
                VStack(spacing: 16) {
                    Button(action: {
                        showFriendSelection = true
                    }) {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("event_share_action.select_friends_to_share".localized())
                            Spacer()
                            if !selectedFriends.isEmpty {
                                Text("event_share_action.friends_count".localized(with: selectedFriends.count))
                                    .foregroundColor(.blue)
                            }
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: {
                        generateShareLink()
                    }) {
                        HStack {
                            Image(systemName: "link")
                            Text("event_share_action.generate_share_link".localized())
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: {
                        prepareSystemShare()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("event_share_action.system_share".localized())
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                if let message = errorMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .padding()
                }
                
                if showSuccessMessage {
                    Text("event_share_action.share_success".localized())
                        .foregroundColor(.green)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("分享活动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFriendSelection) {
                NavigationView {
                    FriendSelectionView(selectedFriends: $selectedFriends, onComplete: {
                        showFriendSelection = false
                        if !selectedFriends.isEmpty {
                            shareWithSelectedFriends()
                        }
                    })
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(activityItems: [shareText])
            }
        }
    }
    
    private func shareWithSelectedFriends() {
        guard !selectedFriends.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await EventManager.shared.shareEventWithFriends(
                    eventId: event.id ?? 0,
                    friendIds: selectedFriends,
                    senderId: userManager.userOpenId
                )
                
                await MainActor.run {
                    showSuccessMessage = true
                    isLoading = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSuccessMessage = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "分享失败：\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func generateShareLink() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let link = try await InviteLinkManager.shared.generateEventInviteLink(
                    eventId: event.id ?? 0,
                    eventTitle: event.title,
                    creatorId: userManager.userOpenId
                )
                let shareText = InviteLinkManager.shared.generateShareText(event: event, inviteLink: link)
                await MainActor.run {
                    self.shareText = shareText
                    isLoading = false
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "生成分享連結失敗：\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func prepareSystemShare() {
        let shareText = """
        邀请你参加活动：\(event.title)
        时间：\(event.date) \(event.startTime) - \(event.endTime)
        地点：\(event.destination)
        """
        self.shareText = shareText
        showShareSheet = true
    }
}

// 你可以根据实际情况补充 FriendSelectionView 和 ShareSheet 组件
