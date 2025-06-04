//
//  RootView.swift
//  Secalender
//
//  Created by linping on 2024/6/14.
//

import SwiftUI

struct RootView: View {
    @Binding var showSignInView: Bool

    var body: some View {
        ZStack {
            if !showSignInView {
                NavigationStack {
                    ContentView()
                }
            }
        }
        .onAppear {
            let authUser = try? AuthenticationManager.shared.getAuthenticatedUser()
            self.showSignInView = authUser == nil
        }
        .fullScreenCover(isPresented: $showSignInView) {
            AuthenticationView(showSignInView: $showSignInView)
        }
    }
}

#Preview {
    RootView(showSignInView: .constant(false))
}
