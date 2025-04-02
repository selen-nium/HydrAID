//
//  SignUp.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//

import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Binding var showingSignUp: Bool
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 30)
            
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            
            SecureField("Confirm Password", text: $confirmPassword)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
            
            Button(action: handleSignUp) {
                Text("Sign Up")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
            Button(action: {
                showingSignUp = false
            }) {
                Text("Already have an account? Login")
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if alertTitle == "Verification Email Sent" {
                        showingSignUp = false
                    }
                }
            )
        }
    }
    
    private func handleSignUp() {
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please fill in all fields"
            showAlert = true
            return
        }
        
        guard password == confirmPassword else {
            alertTitle = "Error"
            alertMessage = "Passwords do not match"
            showAlert = true
            return
        }
        
        authService.signUp(email: email, password: password) { result in
            switch result {
            case .success(let user):
                // Send verification email
                user.sendEmailVerification { error in
                    if let error = error {
                        alertTitle = "Error"
                        alertMessage = "Failed to send verification email: \(error.localizedDescription)"
                        showAlert = true
                        return
                    }
                    
                    alertTitle = "Verification Email Sent"
                    alertMessage = "Please check your email to verify your account before logging in."
                    showAlert = true
                }
            case .failure(let error):
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(showingSignUp: .constant(true))
            .environmentObject(AuthenticationService())
    }
}
