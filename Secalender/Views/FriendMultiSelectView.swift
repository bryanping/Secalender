//
//  FriendMultiSelectView.swift
//  Secalender
//
//  Created by 林平 on 2025/6/5.
//

import SwiftUI

struct FriendMultiSelectView: View {
    var allFriends: [String] // 所有好友的 email 或 openid
    @Binding var selectedFriends: [String]

    var body: some View {
        List {
            ForEach(allFriends, id: \.self) { friend in
                MultipleSelectionRow(title: friend, isSelected: selectedFriends.contains(friend)) {
                    if selectedFriends.contains(friend) {
                        selectedFriends.removeAll { $0 == friend }
                    } else {
                        selectedFriends.append(friend)
                    }
                }
            }
        }
        .navigationTitle("选择好友")
    }
}

struct MultipleSelectionRow: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}
