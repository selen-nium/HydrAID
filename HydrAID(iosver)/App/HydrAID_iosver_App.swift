//
//  HydrAID_iosver_App.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//

import SwiftUI
import Firebase

@main
struct HydrAID_iosver_App: App {
    init () {
        FirebaseApp.configure()
    }
    
//    @StateObject private var authService = AuthenticationService()
    @StateObject private var bleManager = BLEManager()
    
    var body: some Scene {
        WindowGroup {
            Home()
//                .environmentObject(authService)
                .environmentObject(bleManager)
        }
    }
}
