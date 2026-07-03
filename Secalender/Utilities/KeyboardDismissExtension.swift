//
//  KeyboardDismissExtension.swift
//  Secalender
//
//  鍵盤收起擴展：滑動頁面、點擊空白處、提交時收鍵盤
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 全局收起鍵盤（適用於有 TextField/TextEditor 的頁面）
func hideKeyboard() {
    #if canImport(UIKit)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
}

extension View {
    /// 點擊空白處收鍵盤的修飾符（需搭配 ScrollView 的 scrollDismissesKeyboard 使用）
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded { hideKeyboard() }
        )
    }
}
