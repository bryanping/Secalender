//
//  AuthenticationView.swift
//  Secalender
//
//  Created by linping on 2024/6/13.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct AuthenticationView: View {
    
    @StateObject private var viewModle = AuthenticationViewModel()
    @Binding var showSignInView: Bool
    
    var body: some View {
        VStack {

            Button(action: {
                Task {
                    do {
                        try await viewModle.signInAnonymous()
                        showSignInView = false
                    } catch {
                        print(error)
                    }
                }
                
            }, label: {
                Text("Sign In Anonymously")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(height: 55)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(10)
            })
           
            
            NavigationLink {
                SignInEmailView(showSignInView: $showSignInView)
            } label: {
                Text("Sign In With Email")
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
            
            Button(action: {
                Task {
                    do {
                        try await viewModle.signInApple()
                        showSignInView = false
                    } catch {
                        print(error)
                        
                    }
                }
                
            }, label: {
                SignInWithAppleButtonViewRepresentable(type: .default, style: .white)
                    .allowsTightening(false)
            })
            .frame(height: 55)
            
            
            Spacer()
        }
        .padding()
        .navigationTitle("Sign In")
        
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
