//
//  Utilities.swift
//  Secalender
//
//  Created by linping on 2024/6/20.
//

import Foundation
import UIKit

final class Utilities {
    
    static let shared = Utilities()
    private init () {}
    
    
    @MainActor
    func topViewController(controller: UIViewController? = nil) -> UIViewController? {
        // 使用场景 API 替代已弃用的 keyWindow（iOS 13+）
        let rootViewController: UIViewController?
        if let providedController = controller {
            rootViewController = providedController
        } else {
            // 尝试从场景获取 key window
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                rootViewController = window.rootViewController
            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first {
                // 如果没有 key window，使用第一个窗口
                rootViewController = window.rootViewController
            } else {
                rootViewController = nil
            }
        }
        
        guard let controller = rootViewController else {
            return nil
        }
         
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}

// MARK: - 修改内容：Phase 1-A — 持久化日期字串專用 formatter
// 裝置若為佛曆/和曆（zh_TW@calendar=buddhist 等）或非公曆設定，
// 預設 DateFormatter 會把 "yyyy" 寫成 2569 等錯誤年份存進 Firebase。
// 所有「寫入/解析儲存字串」一律使用此工廠；純顯示用 formatter 不受影響。
extension DateFormatter {
    static func stable(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }
}
