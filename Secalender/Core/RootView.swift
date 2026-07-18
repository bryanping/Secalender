//
//  RootView.swift
//  Secalender
//
//  Created by linping on 2024/6/14.
//

import SwiftUI
import FirebaseAuth

/// 用於 sheet(item:) 的包裝，使 PendingDeepLink 可 Identifiable
private struct PendingDeepLinkItem: Identifiable {
    var id: String {
        switch link {
        case .addFriend(let code): return "friend-\(code)"
        case .eventShare(let event): return "event-\(event.id ?? 0)"
        case .eventShareError(let message): return "error-\(message.hashValue)"
        case .addTimeItem(let title, let start, _, _, _): return "additem-\(title)-\(start.timeIntervalSince1970)"  // 修改内容：時事活動
        case .importCalendar(let url, _): return "importcal-\(url.absoluteString.hashValue)"  // 修改内容：ICS 匯入
        }
    }
    let link: PendingDeepLink
    init?(_ link: PendingDeepLink?) {
        guard let link = link else { return nil }
        self.link = link
    }
}

struct RootView: View {
    @Binding var showSignInView: Bool
    @EnvironmentObject var userManager: FirebaseUserManager
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator.shared

    var body: some View {
        Group {
            if showSignInView {
                NavigationStack {
                    AuthenticationView(showSignInView: $showSignInView)
                }
            } else {
                ContentView()
            }
        }
        .onAppear {
            Task {
                await checkAuthStatus()
            }
        }
        .sheet(item: Binding(
            get: { deepLinkCoordinator.pendingLink.flatMap { PendingDeepLinkItem($0) } },
            set: { if $0 == nil { deepLinkCoordinator.clearPendingLink() } }
        )) { item in
            Group {
                switch item.link {
                case .addFriend(let code):
                    AddFriendView(prefilledInviteCode: code)
                        .environmentObject(userManager)
                        .onDisappear { deepLinkCoordinator.clearPendingLink() }
                case .eventShare(let event):
                    NavigationStack {
                        EventShareView(event: event, onEventUpdated: nil)
                            .environmentObject(userManager)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("settings.ok".localized()) {
                                        deepLinkCoordinator.clearPendingLink()
                                    }
                                }
                            }
                    }
                // 修改内容：時事活動 — 深鏈加入行程確認頁
                case .addTimeItem(let title, let start, let end, let location, let notes):
                    DeepLinkAddTimeItemView(title: title, start: start, end: end, location: location, notes: notes) {
                        deepLinkCoordinator.clearPendingLink()
                    }
                    .presentationDetents([.medium])
                // 修改内容：ICS 匯入 — 日曆預覽選擇頁
                case .importCalendar(let url, let title):
                    DeepLinkCalendarImportView(icsURL: url, calendarTitle: title) {
                        deepLinkCoordinator.clearPendingLink()
                    }
                    .environmentObject(userManager)
                case .eventShareError(let message):
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(message)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("settings.ok".localized()) {
                            deepLinkCoordinator.clearPendingLink()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func checkAuthStatus() async {
        guard let user = try? AuthenticationManager.shared.getAuthenticatedUser() else {
            await MainActor.run {
                showSignInView = true
            }
            return
        }
        
        await MainActor.run {
            showSignInView = false
            if userManager.userOpenId != user.uid {
                userManager.userOpenId = user.uid
                userManager.refresh()
            }
        }
    }
}



#Preview {
    RootView(showSignInView: .constant(false))
        .environmentObject(FirebaseUserManager.shared)
}
