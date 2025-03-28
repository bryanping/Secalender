//
//  MemberView.swift
//  Secalender
//
//  Created by linping on 2024/6/24.
//

import SwiftUI

struct MemberView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("社群功能")) {
                    NavigationLink(destination: AddFriendView()) {
                        Label("添加好友", systemImage: "person.badge.plus")
                    }

                    NavigationLink(destination: ReceivedFriendRequestsView()) {
                        Label("收到的好友请求", systemImage: "envelope.open")
                    }
                }
            }
            .navigationTitle("功能")
        }
    }
}

struct MemberView_Previews: PreviewProvider {
    static var previews: some View {
        MemberView()
    }
}

