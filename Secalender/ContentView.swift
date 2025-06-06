//
//  ContentView.swift
//  Secalender
//
//  Created by linping on 2024/6/12.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1  // <- 加上可变状态
    @EnvironmentObject var userManager: FirebaseUserManager

    var body: some View {
        TabView(selection: $selectedTab) {  // <- 改为绑定变量
            CalendarView()
                .tabItem { Text("行事历") }
                .tag(1)

            CommunityView()
                .tabItem { Text("社群") }
                .tag(2)

            MemberView()
                .tabItem { Text("功能") }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FirebaseUserManager())
}
