//
//  AuthenticationView.swift
//  Secalender
//
//  Created by linping on 2024/6/13.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

@MainActor
final class AuthenticationViewModel: ObservableObject {
    
    
    func signInGoogle() async throws {
        let helper = SignInGoogleHelper()
        let tokens = try await helper.signIn()
        
        try await AuthenticationManager.shared.signInWithGoogle(tokens: tokens)
    }
     
}
    
struct AuthenticationView: View {
    
    @StateObject private var viewModle = AuthenticationViewModel()
    @Binding var showSignInView: Bool
    var body: some View {
        VStack {
            
            NavigationLink {
                SignInEmailView(showSignInView: $showSignInView)
                
            } label: {
                Text("Sing In With Email")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .light, style: .wide, state: .normal)){
                Task {
                    do {
                        try await viewModle.signInGoogle()
                        showSignInView = false
                    } catch {
                        print(error)
                        
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Sing In")
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            AuthenticationView(showSignInView: .constant(false))
        }
    }
}

#Preview {
    AuthenticationView(showSignInView: .constant(false))
}
