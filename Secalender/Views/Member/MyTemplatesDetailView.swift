//
//  MyTemplatesDetailView.swift
//  Secalender
//
//  我的模板：上架/待審/下架
//  包裝 MyTemplatesView 供 Member 資產入口使用
//

import SwiftUI

struct MyTemplatesDetailView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    
    var body: some View {
        MyTemplatesView()
            .environmentObject(userManager)
            .navigationTitle("member.assets_templates".localized())
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        MyTemplatesDetailView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
