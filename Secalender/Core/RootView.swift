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

    var body: some View {
        Group {
            if showSignInView {
                AuthenticationView(showSignInView: $showSignInView)
            } else {
                ContentView()
            }
        }
        .onAppear {
            checkAuthStatus()
        }
    }

    private func checkAuthStatus() {
        Task {
            let authUser = try? AuthenticationManager.shared.getAuthenticatedUser()
            DispatchQueue.main.async {
                self.showSignInView = authUser == nil
            }
            if let user = authUser {
                // 登入後主動載入 Firestore 資料
                FirebaseUserManager.shared.userOpenId = user.uid
                FirebaseUserManager.shared.refresh()
            }
        }
    }
}



#Preview {
    RootView(showSignInView: .constant(false))
        .environmentObject(FirebaseUserManager.shared)
}
