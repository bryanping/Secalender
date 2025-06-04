//
//  MemberView.swift
//  Secalender
//
//  Created by linping on 2024/7/1.
//

import SwiftUI
import Firebase

struct MemberView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var showSignInView: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - 用户信息
                Section {
                    HStack {
                        if let photoUrl = userManager.photoUrl, let url = URL(string: photoUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                     .scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(userManager.displayName ?? userManager.alias ?? "用户")
                                .font(.headline)
                            if let email = userManager.alias {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 4)
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

                // MARK: - 分享功能
                Section(header: Text("分享")) {
                    NavigationLink(destination: ShareHistoryView()) {
                        Label("分享历史", systemImage: "square.and.arrow.up")
                    }
                    NavigationLink(destination: ShareNotificationsView()) {
                        Label("分享通知", systemImage: "bell")
                    }
                    NavigationLink(destination: EventInvitationsView()) {
                        Label("活动邀请", systemImage: "calendar.badge.plus")
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
