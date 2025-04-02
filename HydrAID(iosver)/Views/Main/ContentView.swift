//
//  ContentView.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

enum AppView {
    case authentication
    case profileSetup
    case mainApp
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var currentView: AppView = .authentication
    @State private var isCheckingUser = true
    
    var body: some View {
        Group {
            if isCheckingUser {
                // Loading view while checking user state
                LoadingView(message: "Checking authentication...")
                    .onAppear {
                        checkUserState()
                    }
            } else {
                switch currentView {
                case .authentication:
                    AuthenticationView(onCompleteProfileSetup: {
                        currentView = .profileSetup
                    })
                case .profileSetup:
                    ProfileSetupView(onComplete: {
                        currentView = .mainApp
                    })
                case .mainApp:
                    MainTabView()
                }
            }
        }
        // Add the onChange modifier here, properly scoped to access all needed variables
        .onChange(of: authService.isAuthenticated) { newValue in
            print("Auth state change detected in ContentView: \(newValue)")
            if !newValue {
                // User signed out, go to authentication
                currentView = .authentication
            } else if newValue && currentView == .authentication {
                // User just signed in, recheck profile status
                isCheckingUser = true
                checkUserState()
            }
        }
    }
    
    private func checkUserState() {
        // Check if user is authenticated
        if let user = Auth.auth().currentUser {
            // User is authenticated, check if email is verified
            if user.isEmailVerified {
                // Email is verified, check if profile is set up
                checkProfileSetup(userId: user.uid)
            } else {
                // Email is not verified, show authentication view
                isCheckingUser = false
                currentView = .authentication
            }
        } else {
            // No user is signed in
            isCheckingUser = false
            currentView = .authentication
        }
    }
    
    private func checkProfileSetup(userId: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            isCheckingUser = false
            
            if let error = error {
                print("Error checking profile: \(error.localizedDescription)")
                currentView = .authentication
                return
            }
            
            if let snapshot = snapshot,
               snapshot.exists,
               let data = snapshot.data(),
               let setupCompleted = data["setupCompleted"] as? Bool,
               setupCompleted {
                // Profile is set up, go to main app
                currentView = .mainApp
            } else {
                // Profile is not set up, go to profile setup
                currentView = .profileSetup
            }
        }
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text(message)
                .foregroundColor(.secondary)
        }
    }
}

struct AuthenticationView: View {
    @State private var showingSignUp = false
    let onCompleteProfileSetup: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                if showingSignUp {
                    SignUpView(showingSignUp: $showingSignUp)
                } else {
                    LoginView(showingSignUp: $showingSignUp, onCompleteProfileSetup: onCompleteProfileSetup)
                }
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var bleManager: BLEManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            StatisticsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthenticationService())
    }
}
