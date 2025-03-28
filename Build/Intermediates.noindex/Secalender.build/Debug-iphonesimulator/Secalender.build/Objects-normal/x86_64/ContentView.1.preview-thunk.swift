import func SwiftUI.__designTimeFloat
import func SwiftUI.__designTimeString
import func SwiftUI.__designTimeInteger
import func SwiftUI.__designTimeBoolean

#sourceLocation(file: "/Users/linping/Desktop/活動歷/MyFirstProgram/Secalender/Secalender/ContentView.swift", line: 1)
//
//  ContentView.swift
//  Secalender
//
//  Created by linping on 2024/6/12.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1  // <- 加上可变状态

    var body: some View {
        TabView(selection: $selectedTab) {  // <- 改为绑定变量
            CalendarView()
                .tabItem { Text(__designTimeString("#1980_0", fallback: "行事历")) }
                .tag(__designTimeInteger("#1980_1", fallback: 1))

            ActivityView()
                .tabItem { Text(__designTimeString("#1980_2", fallback: "活动")) }
                .tag(__designTimeInteger("#1980_3", fallback: 2))

            MemberView()
                .tabItem { Text(__designTimeString("#1980_4", fallback: "功能")) }
                .tag(__designTimeInteger("#1980_5", fallback: 3))
        }
    }
}

#Preview {
    ContentView()
}
