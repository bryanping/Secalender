//
//  InviteFriendView.swift
//  Secalender
//
//  Created by ChatGPT on 2025/6/6.
//
import SwiftUI
import Firebase

struct InviteFriendView: View {
    @Binding var selectedIds: [String]
    @EnvironmentObject var userManager: FirebaseUserManager
    @Environment(\.dismiss) var dismiss

    @State private var allFriends: [FriendEntry] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(allFriends, id: \.id) { friend in
                    Button {
                        let id = friend.id
                        if selectedIds.contains(id) {
                            selectedIds.removeAll { $0 == id }
                        } else {
                            selectedIds.append(id)
                        }
                    } label: {
                        HStack {
                            if let urlStr = friend.photoUrl, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                            }

                            VStack(alignment: .leading) {
                                Text(friend.alias ?? friend.email ?? "未知")
                                    .font(.headline)
                                if let email = friend.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }

                            Spacer()

                            if selectedIds.contains(friend.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择分享对象")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    self.allFriends = await (try? userManager.fetchFriendDetails()) ?? []
                }
            }
        }
    }
}
