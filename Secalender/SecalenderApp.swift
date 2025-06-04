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
    
    init() {
        // Configuration is handled in AppDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(FirebaseUserManager.shared)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
   
    return true
  }
}
