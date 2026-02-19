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
                Section(header: Text("profile.basic_info".localized())) {
                    if let userCode = user.userCode {
                        HStack {
                            Text("profile.user_id".localized())
                            Spacer()
                            Text(userCode)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    
                    // 優先顯示 displayName，如果沒有則顯示 name
                    if let displayName = user.displayName, !displayName.isEmpty {
                        HStack {
                            Text("profile.display_name".localized())
                            Spacer()
                            Text(displayName)
                                .foregroundColor(.secondary)
                        }
                    } else if let name = user.name, !name.isEmpty {
                        HStack {
                            Text("profile.display_name".localized())
                            Spacer()
                            Text(name)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let gender = user.gender, !gender.isEmpty {
                        HStack {
                            Text("profile.gender".localized())
                            Spacer()
                            Text(gender == "Male" ? "profile.male".localized() : (gender == "Female" ? "profile.female".localized() : "profile.unknown".localized()))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let phone = user.phone, !phone.isEmpty {
                        HStack {
                            Text("profile.phone".localized())
                            Spacer()
                            Text(phone)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let region = user.region, !region.isEmpty {
                        HStack {
                            Text("profile.region".localized())
                            Spacer()
                            Text(region)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let favoriteTags = user.favoriteTags, !favoriteTags.isEmpty {
                    Section(header: Text("profile.favorite_tags".localized())) {
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
                        Label("profile.edit_profile".localized(), systemImage: "pencil")
                    }
                }
            }
        }
        .task {
            try? await viewModel.loadCurrentUser()
        }
        .navigationTitle("profile.title".localized())
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

