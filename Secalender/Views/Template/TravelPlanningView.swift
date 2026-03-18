//
//  TravelPlanningView.swift
//  Secalender
//
//  旅遊行程主題入口：內嵌完整四步驟行程規劃（TravelPlannerContent），
//  與 AIPlannerView 的旅遊流程一致。AIPlannerView 日後可改為時間管理總入口。
//

import SwiftUI

/// 旅遊行程主題視圖：自包含完整行程生成機制（目的地→偏好→細節→AI 生成），非僅連結。
struct TravelPlanningView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        TravelPlannerContent()
            .environmentObject(userManager)
    }
}

#Preview {
    TravelPlanningView()
        .environmentObject(MockFirebaseUserManager.shared)
}
