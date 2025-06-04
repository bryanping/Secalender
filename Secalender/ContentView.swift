//
//  ContentView.swift
//  Secalender
//
//  Created by linping on 2024/6/12.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    @EnvironmentObject var userManager: FirebaseUserManager

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .tabItem { Label("行事曆", systemImage: "calendar") }
                .tag(1)

            CommunityView()
                .tabItem { Label("社群", systemImage: "person.3") }
                .tag(2)

            TemplateStoreView()
                .tabItem { Label("模板市集", systemImage: "bag") }
                .tag(3)

            AIPlannerView()
                .tabItem { Label("智能規劃", systemImage: "sparkles") }
                .tag(4)

            AchievementsView()
                .tabItem { Label("任務成就", systemImage: "star") }
                .tag(5)

            MemberView()
                .tabItem { Label("功能", systemImage: "gearshape") }
                .tag(6)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
