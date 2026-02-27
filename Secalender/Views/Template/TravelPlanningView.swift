//
//  TravelPlanningView.swift
//  Secalender
//
//  Created by 林平 on 2025/8/8.
//  快速主题入口：與 AIPlannerView 同等功能的行程規劃視圖
//

import SwiftUI

/// 快速主题中的行程規劃視圖，功能與 AIPlannerView 相同
struct TravelPlanningView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        AIPlannerView()
            .environmentObject(userManager)
    }
}

#Preview {
    TravelPlanningView()
        .environmentObject(MockFirebaseUserManager.shared)
}
