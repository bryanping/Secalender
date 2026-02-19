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
