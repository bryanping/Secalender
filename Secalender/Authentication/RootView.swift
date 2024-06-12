//
//  RootView.swift
//  Secalender
//
//  Created by linping on 2024/6/14.
//

import SwiftUI

struct RootView: View {
    
    @State private var showSignInView: Bool = false
    
    var body: some View {
        
            ZStack {
                if !showSignInView{
                    NavigationStack {
                        SettingsView(showSignInView: $showSignInView)
                    }
                }
            }
            .onAppear {
                let authUser = try? AuthenticationManager.shared.getAuthenticatedUser ()
                self.showSignInView = authUser == nil
            }
            .fullScreenCover(isPresented: $showSignInView) { 
                NavigationStack {
                    AuthenticationView(showSignInView: $showSignInView)
                }
            }
    }
}

#Preview {
    RootView()
}
