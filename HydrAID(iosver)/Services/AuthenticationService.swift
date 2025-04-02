//
//  AuthenticationService.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//
import Foundation
import FirebaseAuth
import Combine

class AuthenticationService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated = false
    
    init() {
        // Listen for authentication state changes
        FirebaseAuth.Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            print("Auth state changed: user \(user != nil ? "logged in" : "logged out")")
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("Sign in error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let user = authResult?.user {
                print("Sign in successful for user: \(user.uid)")
                // Explicitly update the published properties to force UI updates
                DispatchQueue.main.async {
                    self.user = user
                    self.isAuthenticated = true
                }
                completion(.success(user))
            }
        }
    }
    
    func signUp(email: String, password: String, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("Sign up error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let user = authResult?.user {
                print("Sign up successful for user: \(user.uid)")
                // Explicitly update the published properties to force UI updates
                DispatchQueue.main.async {
                    self.user = user
                    self.isAuthenticated = true
                }
                completion(.success(user))
            }
        }
    }
    
    func signOut() {
        do {
            try FirebaseAuth.Auth.auth().signOut()
            // Explicitly update the published properties to force UI updates
            DispatchQueue.main.async {
                self.user = nil
                self.isAuthenticated = false
                print("Sign out successful")
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
