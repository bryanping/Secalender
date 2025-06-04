//
//  SecalenderApp.swift
//  Secalender
//
//  Created by linping on 2024/6/12.
//

import SwiftUI
import Firebase

@main
struct SecalenderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var userManager = FirebaseUserManager.shared
    @State private var showSignInView: Bool = false

    var body: some Scene {
        WindowGroup {
            RootView(showSignInView: $showSignInView)
                .environmentObject(userManager)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "secalender" else { return }
        
        if url.host == "location" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let addressItem = components?.queryItems?.first(where: { $0.name == "address" }),
               let address = addressItem.value {
                // 通过通知中心发送地址数据
                NotificationCenter.default.post(
                    name: NSNotification.Name("LocationSelected"),
                    object: nil,
                    userInfo: ["address": address]
                )
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

