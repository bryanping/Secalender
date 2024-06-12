//
//  SettingsView.swift
//  Secalender
//
//  Created by linping on 2024/6/14.
//

import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    
    @Published var authProviders: [AuthProviderOption] = []
    
    func loadAuthProviders() {
        if let providers = try? AuthenticationManager.shared.getProviders() {
            authProviders = providers
        }
    }
    
    func signOut() throws {
        try AuthenticationManager.shared.signOut()
    }
    
    func resetPassword() async throws {
        let authUser = try AuthenticationManager.shared.getAuthenticatedUser()
        
        guard let email = authUser.email else {
            throw URLError(.fileDoesNotExist)
        }
        try await AuthenticationManager.shared.resetPassword(email: email)
    }
    func updateEmail() async throws {
        let email = "text@email.com"
        try await AuthenticationManager.shared.updateEmail(email: email)
    }
    func updatePassword() async throws {
        let password = "hello123"
        try await AuthenticationManager.shared.updatePassword(password: password)
    }
}

struct SettingsView: View {
    
    @StateObject private var viewModel = SettingsViewModel()
    @Binding var showSignInView: Bool
    
    var body: some View {
        List{
            Button("Log Out") {
                Task {
                    do{
                        try viewModel.signOut()
                        showSignInView = true
                    } catch {
                        print(error)
                    }
                }
            }
            if viewModel.authProviders.contains(.email) {
                emailSection
            }
        }
        
        .onAppear {
            viewModel.loadAuthProviders()
        }
        .navigationBarTitle("Setting")
    }
}

#Preview {
    SettingsView(showSignInView: .constant(false))
}


extension SettingsView {
    
    private var emailSection: some View {
        
        Section {
            Button("Reset Password") {
                Task {
                    do{
                        try await viewModel.resetPassword()
                        print("Password Reset!")
                    } catch {
                        print(error)
                    }
                }
            }
            Button("Update Password") {
                Task {
                    do{
                        try await viewModel.updatePassword()
                        print("Password Updated!")
                    } catch {
                        print(error)
                    }
                }
            }
            Button("Update Email") {
                Task {
                    do{
                        try await viewModel.updateEmail()
                        print("Email Updated!")
                    } catch {
                        print(error)
                    }
                }
            }
        } header: {
            Text("Email functions")
        }
    }
}
