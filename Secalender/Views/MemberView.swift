//
//  MemberView.swift
//  Secalender
//
//  Created by linping on 2024/6/24.
//

import SwiftUI
import Firebase

struct MemberView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showSignInView: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - 使用者基本资料区块
                Section {
                    HStack(spacing: 16) {
                        AsyncImage(url: URL(string: userManager.photoUrl ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(userManager.displayName ?? "未命名")
                                .font(.headline)
                            Text("ID: \(userManager.alias ?? "无")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        NavigationLink(destination: EditProfileView()) {
                            Image(systemName: "pencil")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - 好友功能
                Section(header: Text("好友")) {
                    NavigationLink(destination: AddFriendView()) {
                        Label("添加好友", systemImage: "person.badge.plus")
                    }
                    NavigationLink(destination: MyFriendListView()) {
                        Label("好友清单", systemImage: "person.3.fill")
                    }
                    NavigationLink(destination: ReceivedFriendRequestsView()) {
                        Label("收到的请求", systemImage: "envelope")
                    }
                }

                // MARK: - 社群功能
                Section(header: Text("社群")) {
                    NavigationLink(destination: CommunityView()) {
                        Label("社群行程", systemImage: "person.2.wave.2.fill")
                    }
                }

                // MARK: - 设定
                Section(header: Text("设定")) {
                    NavigationLink(destination: SettingsView(showSignInView: $showSignInView)) {
                        Label("设定", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("功能")
            .onAppear {
                userManager.refresh()
            }
        }
    }
}

struct MemberView_Previews: PreviewProvider {
    static var previews: some View {
        MemberView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
