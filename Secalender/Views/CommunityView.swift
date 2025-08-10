//
//  CommunityView.swift
//  Secalender
//
//  Created by linping on 2025/5/29.
//
import SwiftUI

enum CommunityTab: Int, CaseIterable {
    case friends, groups, nearby
    var title: String {
        switch self {
        case .friends: return "朋友分享"
        case .groups:  return "社群分享"
        case .nearby:  return "附近活動"
        }
    }
}

struct CommunityView: View {
    @EnvironmentObject var userManager: FirebaseUserManager
    @State private var selectedTab: CommunityTab = .friends
    @Namespace private var underlineNamespace

    var body: some View {
        VStack(spacing: 0) {
            // 上方自定義 Tab Bar
            HStack {
                ForEach(CommunityTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation { selectedTab = tab }
                    } label: {
                        VStack(spacing: 4) {
                            Text(tab.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedTab == tab ? .primary : .gray)
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.green)
                                    .matchedGeometryEffect(id: "underline", in: underlineNamespace)
                                    .frame(height: 4)
                                    .offset(y: 2)
                            } else {
                                Capsule().fill(Color.clear).frame(height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.horizontal)
            .background(Color.white)
            Divider()

            // 分頁內容
            TabView(selection: $selectedTab) {
                FriendEventsView().tag(CommunityTab.friends)
                GroupEventsView().tag(CommunityTab.groups)
                NearbyEventsView().tag(CommunityTab.nearby)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("社群互動")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selectedTab == .friends {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AddFriendView()) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            } else if selectedTab == .groups {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AddGroupView()) {
                        Image(systemName: "person.3.fill")
                    }
                }
            }
        }
    }
}



struct CommunityView_Previews: PreviewProvider {
    static var previews: some View {
        CommunityView()
            .environmentObject(FirebaseUserManager.shared)
    }
}
