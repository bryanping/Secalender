//
//  ContentView.swift
//  Secalender
//
//  Created by linping on 2024/6/12.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView(selection: /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Selection@*/.constant(1)/*@END_MENU_TOKEN@*/) {

            CalendarView()
                .tabItem { Text("行事历") }.tag(1)
            ActivityView()
                .tabItem { Text("活动") }.tag(2)
            MemberView()
                .tabItem { Text("功能") }.tag(3)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
