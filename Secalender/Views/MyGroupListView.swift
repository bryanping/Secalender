//
//  MyGroupListView.swift
//  Secalender
//
//  Created by 林平 on 2025/6/7.
//

import SwiftUI

struct MyGroupListView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var groups: [Group] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView("载入中…")
            } else if let error = errorMessage {
                Text("错误: \(error)").foregroundColor(.red)
            } else if groups.isEmpty {
                Text("目前没有加入任何群组")
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading) {
                        Text(group.name).font(.headline)
                        Text("成员数量：\(group.memberIds.count)").font(.subheadline).foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("我的群组")
        .onAppear {
            loadGroups()
        }
    }

    private func loadGroups() {
        GroupManager.shared.fetchGroups(forUserId: userManager.userOpenId) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let groups):
                    self.groups = groups
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
