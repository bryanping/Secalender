//
//  SecalenderApp.swift
//  Secalender
//
//  Created by linping on 2024/6/12.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleMaps
import GooglePlaces
import UserNotifications

@main
struct SecalenderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var userManager = FirebaseUserManager.shared
    @StateObject private var localization = LocalizationManager.shared
    @State private var showSignInView: Bool = false

    var body: some Scene {
        WindowGroup {
            RootView(showSignInView: $showSignInView)
                .environmentObject(userManager)
                .environmentObject(localization)
                .environment(\.locale, Locale(identifier: localization.localeIdentifier)) // 驱动 SwiftUI 刷新
                .id(localization.localeIdentifier) // 强制刷新整棵 SwiftUI 树
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        SyncQueueService.shared.triggerSyncIfNeeded()
                    }
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // 支援分享連結：secalender:// 與 https://secalender.app
        let isShareLink = (url.scheme == "secalender" && ["friend", "invite", "event"].contains(url.host))
            || (url.host?.hasSuffix("secalender.app") == true)
        if isShareLink {
            Task { @MainActor in
                _ = DeepLinkCoordinator.shared.handleURL(url)
            }
            return
        }
        
        if url.scheme == "secalender", url.host == "location" {
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
        // Firestore 預設已啟用離線持久化，減少重複讀取與流量

        // 初始化 Google Maps 和 Places API
        // 从 Info.plist 读取 API Key（通过 Secrets.xcconfig 配置）
        var apiKeyFound = false
        
        if let apiKey = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String,
           !apiKey.isEmpty,
           apiKey != "$(GOOGLE_MAPS_API_KEY)" {  // 检查是否被正确替换
            GooglePlacesManager.configure(apiKey: apiKey)
            apiKeyFound = true
            #if DEBUG
            print("✅ Google Maps API Key 已从 Info.plist 加载")
            #endif
        } else if let path = Bundle.main.path(forResource: "GoogleService-Info.plist", ofType: nil),
                  let plist = NSDictionary(contentsOfFile: path),
                  let apiKey = plist["API_KEY"] as? String,
                  !apiKey.isEmpty {
            // 备用：从 GoogleService-Info.plist 读取
            GooglePlacesManager.configure(apiKey: apiKey)
            apiKeyFound = true
            #if DEBUG
            print("✅ Google Maps API Key 已从 GoogleService-Info.plist 加载")
            #endif
        } else if let apiKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"], !apiKey.isEmpty {
            // 备用：从环境变量读取（用于调试）
            GooglePlacesManager.configure(apiKey: apiKey)
            apiKeyFound = true
            #if DEBUG
            print("✅ Google Maps API Key 已从环境变量加载")
            #endif
        }
        
        if !apiKeyFound {
            print("⚠️ 错误: 未找到 Google Maps API Key")
            print("请检查以下配置：")
            print("1. Secrets.xcconfig 文件中的 GOOGLE_MAPS_API_KEY 是否已设置")
            print("2. Info.plist 中是否包含 GOOGLE_MAPS_API_KEY = $(GOOGLE_MAPS_API_KEY)")
            print("3. Xcode 项目 Build Settings 中是否正确引用了 Secrets.xcconfig")
            print("4. GoogleService-Info.plist 中是否包含 API_KEY")
        } else {
            // API Key 已加载，但可能配置不正确
            #if DEBUG
            print("✅ Google Maps API Key 已加载")
            print("📋 应用 Bundle ID: com.Lin-ping.Secalender")
            print("")
            print("⚠️ 如果遇到 REQUEST_DENIED 错误，请检查 API Key 配置：")
            print("   1. 访问 https://console.cloud.google.com/")
            print("   2. 进入 APIs & Services > Credentials")
            print("   3. 编辑你的 API Key")
            print("   4. 在 'Application restrictions' 中选择 'iOS apps'")
            print("   5. 添加 Bundle ID: com.Lin-ping.Secalender")
            print("   6. 确保启用了以下 API：")
            print("      - Maps SDK for iOS")
            print("      - Places API (New)")
            print("      - Geocoding API")
            print("   7. 详细步骤请查看: API_KEY_CONFIGURATION_GUIDE.md")
            #endif
        }
        
        // 同步佇列：App 啟動後若有待同步項目則發出通知，由 EventManager 處理
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SyncQueueNeedsSync"),
            object: nil,
            queue: .main
        ) { _ in
            Task { await EventManager.shared.processSyncQueue() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            SyncQueueService.shared.triggerSyncIfNeeded()
        }
        
        return true
    }
    
    // MARK: - Firebase Auth 远程通知处理（用于手机号验证）
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // 将设备令牌传递给 Firebase Auth
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("注册远程通知失败：\(error.localizedDescription)")
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // 检查是否是 Firebase Auth 的通知
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        
        // 处理其他通知
        completionHandler(.noData)
    }
}

