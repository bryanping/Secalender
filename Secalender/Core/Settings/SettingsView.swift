//
//  SettingsView.swift
//  Secalender
//
//  Created by linping on 2024/6/14.
//

import SwiftUI



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
            
            Button(role: .destructive) {
                Task {
                    do{
                        try await viewModel.deleteAccount()
                        showSignInView = true
                    } catch {
                        print(error)
                    }
                }
            } label: {
                Text("Delete accout")
            }
            
            if viewModel.authProviders.contains(.email) {
                emailSection
            }
            if viewModel.authUser?.isAnonymous == true {
                anonymousSection
                
            }
        }
        
        .onAppear {
            viewModel.loadAuthProviders()
            viewModel.loadAuthUser()
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
    
    private var anonymousSection: some View {
        
        Section {
            Button("Link Google Account") {
                Task {
                    do{
                        try await viewModel.linkGoogleAccount()
                        print("GOOGLE LINKED!")
                    } catch {
                        print(error)
                    }
                }
            }
            Button("Link Apple Account") {
                Task {
                    do{
                        try await viewModel.linkAppleAccount()
                        print("APPLE LINKED!")
                    } catch {
                        print(error)
                    }
                }
            }
            Button("Link Email Account") {
                Task {
                    do{
                        try await viewModel.linkEmailAccount()
                        print("Email LINKED!")
                    } catch {
                        print(error)
                    }
                }
            }
        } header: {
            Text("Create account")
        }
    }
    
}
