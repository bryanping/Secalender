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
