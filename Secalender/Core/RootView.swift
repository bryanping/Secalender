//
//  RootView.swift
//  Secalender
//
//  Created by linping on 2024/6/14.
//

import SwiftUI
import FirebaseAuth

struct RootView: View {
    @Binding var showSignInView: Bool
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var hasCheckedAuth = false // 修改内容：避免重复检查

    var body: some View {
        Group {
            if showSignInView {
                AuthenticationView(showSignInView: $showSignInView)
            } else {
                ContentView()
            }
        }
        .task {
            // 修改内容：使用 task 代替 onAppear，确保只执行一次
            guard !hasCheckedAuth else { return }
            hasCheckedAuth = true
            await checkAuthStatus()
        }
    }

    private func checkAuthStatus() async {
        let authUser = try? AuthenticationManager.shared.getAuthenticatedUser()
        await MainActor.run {
            self.showSignInView = authUser == nil
        }
        // 修改内容：只在用户已登录且 userOpenId 不同时才刷新，避免重复加载
        if let user = authUser, userManager.userOpenId != user.uid {
            userManager.userOpenId = user.uid
            userManager.refresh()
        }
    }
}



#Preview {
    RootView(showSignInView: .constant(false))
        .environmentObject(FirebaseUserManager.shared)
}
