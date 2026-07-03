//
//  CustomThemePlannerView.swift
//  Secalender
//
//  自定義主題行程規劃：使用自定義 AI 指令
//

import SwiftUI

struct CustomThemePlannerView: View {
    let theme: QuickTheme
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        AIPlannerView(customTheme: theme)
            .environmentObject(userManager)
    }
}
