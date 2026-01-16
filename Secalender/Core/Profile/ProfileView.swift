//
//  ProfileView.swift
//  Secalender
//
//  Created by linping on 2024/7/1.
//

import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published private(set) var user: DBUser? = nil
    
    func loadCurrentUser() async throws {
        let authDataResult = try AuthenticationManager.shared.getAuthenticatedUser()
        self.user = try await UserManager.shared.getUser(userId: authDataResult.uid)
    }
}

struct ProfileView: View {
    
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var userManager = FirebaseUserManager.shared
    @Binding var showSignInView: Bool
    
    var body: some View {
        List {
            if let user = viewModel.user {
                Section(header: Text("基本信息")) {
                    if let userCode = user.userCode {
                        HStack {
                            Text("用户ID")
                            Spacer()
                            Text(userCode)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    if let name = user.name, !name.isEmpty {
                        HStack {
                            Text("显示名称")
                            Spacer()
                            Text(name)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let alias = user.alias, !alias.isEmpty {
                        HStack {
                            Text("别名")
                            Spacer()
                            Text(alias)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let gender = user.gender, !gender.isEmpty {
                        HStack {
                            Text("性别")
                            Spacer()
                            Text(gender == "Male" ? "男" : (gender == "Female" ? "女" : "未知"))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let phone = user.phone, !phone.isEmpty {
                        HStack {
                            Text("手机号")
                            Spacer()
                            Text(phone)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let region = user.region, !region.isEmpty {
                        HStack {
                            Text("地区")
                            Spacer()
                            Text(region)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let favoriteTags = user.favoriteTags, !favoriteTags.isEmpty {
                    Section(header: Text("喜好标签")) {
                        let columns = [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ]
                        
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(favoriteTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                    .foregroundColor(.blue)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    NavigationLink {
                        EditProfileView()
                            .environmentObject(userManager)
                    } label: {
                        Label("编辑个人资料", systemImage: "pencil")
                    }
                }
            }
        }
        .task {
            try? await viewModel.loadCurrentUser()
        }
        .navigationTitle("个人资料")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView(showSignInView: $showSignInView)
                } label: {
                    Image(systemName: "gear")
                        .font(.headline)
                } 
            }
        }
    }
}

#Preview {
        NavigationStack {
            ProfileView(showSignInView: .constant(false))
        }
    }

