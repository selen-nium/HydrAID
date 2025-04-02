//
//  Login.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Binding var showingSignUp: Bool
    let onCompleteProfileSetup: () -> Void
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showResendButton: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("HydrAID")
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
            
            Button(action: handleLogin) {
                Text("Login")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
            Button(action: {
                showingSignUp = true
            }) {
                Text("Don't have an account? Sign up")
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)
        }
        .padding()
        .alert(isPresented: $showAlert) {
            showResendButton ?
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                primaryButton: .default(Text("Resend Verification")) {
                    resendVerificationEmail()
                },
                secondaryButton: .cancel(Text("OK"))
            ) :
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func handleLogin() {
        guard !email.isEmpty, !password.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please fill in all fields"
            showResendButton = false
            showAlert = true
            return
        }
        
        authService.signIn(email: email, password: password) { result in
            switch result {
            case .success(let user):
                if !user.isEmailVerified {
                    alertTitle = "Email Not Verified"
                    alertMessage = "Please verify your email before logging in."
                    showResendButton = true
                    showAlert = true
                }
                // Navigation is handled by Home view based on authentication state
                
            case .failure(let error):
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showResendButton = false
                showAlert = true
            }
        }
    }
    
    private func resendVerificationEmail() {
        Auth.auth().currentUser?.sendEmailVerification { error in
            if let error = error {
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showResendButton = false
                showAlert = true
            } else {
                alertTitle = "Success"
                alertMessage = "Verification email sent successfully"
                showResendButton = false
                showAlert = true
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(showingSignUp: .constant(false), onCompleteProfileSetup: {})
            .environmentObject(AuthenticationService())
    }
}
