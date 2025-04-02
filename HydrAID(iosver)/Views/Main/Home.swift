//
//  Home.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// Models for data
struct WeatherData {
    var temperature: Double
    var humidity: Double
    var temperatureUnit: String
    var humidityUnit: String
    var timestamp: String
}

struct IntakeRecommendations {
    var water: WaterRecommendation
    var sugar: SugarRecommendation
    
    struct WaterRecommendation {
        var recommendedLiters: Double
        var adjustmentFactors: [String]
    }
    
    struct SugarRecommendation {
        var recommendedGrams: Double
        var adjustmentFactors: [String]
    }
}

struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var bleManager: BLEManager
    
    @State private var weatherData: WeatherData? = nil
    @State private var recommendations = IntakeRecommendations(
        water: IntakeRecommendations.WaterRecommendation(recommendedLiters: 2.5, adjustmentFactors: []),
        sugar: IntakeRecommendations.SugarRecommendation(recommendedGrams: 25, adjustmentFactors: [])
    )
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var userName: String = "User"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Welcome header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Welcome, \(userName)!")
                                .font(.title)
                                .fontWeight(.bold)
                                .padding(.top)
                            
                            Text("Here's your personalized hydration plan")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Refresh button
                        Button(action: refreshData) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Hydration tracker
                    HydrationTrackerView(
                        recommendedIntake: recommendations.water.recommendedLiters,
                        adjustmentFactors: recommendations.water.adjustmentFactors
                    )
                    .padding(.horizontal)
                    
                    // Sugar intake tracker
                    SugarIntakeTrackerView(
                        recommendedLimit: recommendations.sugar.recommendedGrams,
                        adjustmentFactors: recommendations.sugar.adjustmentFactors
                    )
                    .padding(.horizontal)
                    
                    // Weather info
                    WeatherInfoView(
                        weatherData: weatherData,
                        isLoading: isLoading,
                        error: errorMessage
                    )
                    .padding(.horizontal)
                    
                    // BLE sensor data placeholder
                    BLESensorView()
                        .padding(.horizontal)
                    
                    // Bottom padding for better scrolling
                    Spacer(minLength: 80)
                }
            }
            .navigationBarTitle("HydrAID", displayMode: .inline)
            .navigationBarItems(trailing:
                Button(action: signOut) {
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
            )
            .refreshable {
                await refreshDataAsync()
            }
            .onAppear {
                loadUserData()
                loadWeatherData()
                calculateRecommendations()
            }
        }
    }
    
    // Functions
    private func signOut() {
        authService.signOut()
    }
    
    private func refreshData() {
        Task {
            await refreshDataAsync()
        }
    }
    
    private func refreshDataAsync() async {
        isLoading = true
        
        // Simulate API calls
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        loadUserData()
        loadWeatherData()
        calculateRecommendations()
        
        isLoading = false
    }
    
    private func loadUserData() {
        guard let user = Auth.auth().currentUser else { return }
        
        // Get display name or email prefix
        if let displayName = user.displayName, !displayName.isEmpty {
            userName = displayName
        } else if let email = user.email, !email.isEmpty {
            userName = email.components(separatedBy: "@").first ?? "User"
        }
        
        // Load user profile from Firestore
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user profile: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data() else { return }
            
            // Use user profile data to calculate personalized recommendations
            // This is just a placeholder - you would implement your actual calculation logic
            calculateRecommendations()
        }
    }
    
    private func loadWeatherData() {
        // Simulate fetching weather data
        // In a real app, you would call your weather API here
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Sample data
            weatherData = WeatherData(
                temperature: 28.5,
                humidity: 65.0,
                temperatureUnit: "°C",
                humidityUnit: "%",
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            
            isLoading = false
        }
    }
    
    private func calculateRecommendations() {
        // Simulate calculating personalized recommendations
        // In a real app, you would implement your actual calculation logic from the React Native version
        
        // Example adjustment
        if let weather = weatherData, weather.temperature > 25 {
            recommendations.water.recommendedLiters = 3.0
            recommendations.water.adjustmentFactors = ["High temperature", "Increased activity"]
        } else {
            recommendations.water.recommendedLiters = 2.5
            recommendations.water.adjustmentFactors = ["Normal conditions"]
        }
        
        // Sugar recommendations
        recommendations.sugar.recommendedGrams = 25.0
        recommendations.sugar.adjustmentFactors = ["Health conditions", "Dietary goals"]
    }
}

// MARK: - Component Views

struct HydrationTrackerView: View {
    let recommendedIntake: Double
    let adjustmentFactors: [String]
    @State private var currentIntake: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hydration Tracker")
                .font(.headline)
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(currentIntake * 1000)) ml")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("Goal: \(String(format: "%.1f", recommendedIntake)) L")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 10)
                            .opacity(0.2)
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                        
                        Rectangle()
                            .frame(width: min(CGFloat(currentIntake / recommendedIntake) * geometry.size.width, geometry.size.width), height: 10)
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                            .animation(.linear, value: currentIntake)
                    }
                }
                .frame(height: 10)
            }
            
            // Add water buttons
            HStack(spacing: 8) {
                ForEach([0.1, 0.25, 0.5], id: \.self) { amount in
                    Button(action: {
                        currentIntake = min(currentIntake + amount, recommendedIntake * 1.5)
                    }) {
                        Text("+\(Int(amount * 1000)) ml")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
                
                Button(action: {
                    currentIntake = 0
                }) {
                    Text("Reset")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
            }
            
            // Adjustment factors
            if !adjustmentFactors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendation factors:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(adjustmentFactors, id: \.self) { factor in
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                            Text(factor)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SugarIntakeTrackerView: View {
    let recommendedLimit: Double
    let adjustmentFactors: [String]
    @State private var currentIntake: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sugar Intake Tracker")
                .font(.headline)
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(currentIntake)) g")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("Limit: \(Int(recommendedLimit)) g")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 10)
                            .opacity(0.2)
                            .foregroundColor(.orange)
                            .cornerRadius(5)
                        
                        Rectangle()
                            .frame(width: min(CGFloat(currentIntake / recommendedLimit) * geometry.size.width, geometry.size.width), height: 10)
                            .foregroundColor(currentIntake > recommendedLimit ? .red : .orange)
                            .cornerRadius(5)
                            .animation(.linear, value: currentIntake)
                    }
                }
                .frame(height: 10)
            }
            
            // Add sugar buttons
            HStack(spacing: 8) {
                ForEach([5.0, 10.0, 15.0], id: \.self) { amount in
                    Button(action: {
                        currentIntake = min(currentIntake + amount, recommendedLimit * 2)
                    }) {
                        Text("+\(Int(amount)) g")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                }
                
                Button(action: {
                    currentIntake = 0
                }) {
                    Text("Reset")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
            }
            
            // Adjustment factors
            if !adjustmentFactors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendation factors:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(adjustmentFactors, id: \.self) { factor in
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                            Text(factor)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeatherInfoView: View {
    let weatherData: WeatherData?
    let isLoading: Bool
    let error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Weather")
                .font(.headline)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let weather = weatherData {
                HStack(spacing: 24) {
                    // Temperature
                    VStack {
                        HStack(alignment: .top, spacing: 2) {
                            Text("\(Int(weather.temperature))")
                                .font(.system(size: 40, weight: .medium))
                            Text(weather.temperatureUnit)
                                .font(.headline)
                                .padding(.top, 5)
                        }
                        Text("Temperature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Divider
                    Rectangle()
                        .frame(width: 1, height: 60)
                        .foregroundColor(Color(.systemGray4))
                    
                    // Humidity
                    VStack {
                        HStack(alignment: .top, spacing: 2) {
                            Text("\(Int(weather.humidity))")
                                .font(.system(size: 40, weight: .medium))
                            Text(weather.humidityUnit)
                                .font(.headline)
                                .padding(.top, 5)
                        }
                        Text("Humidity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                Text("No weather data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BLESensorView: View {
    @EnvironmentObject var bleManager: BLEManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Sensors")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "wave.3.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading) {
                        Text("Water Flow")
                            .font(.subheadline)
                        Text("0.5 L / min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Connected")
                        .font(.caption)
                        .padding(6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                }
                
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading) {
                        Text("Water Quality")
                            .font(.subheadline)
                        Text("Clean")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Good")
                        .font(.caption)
                        .padding(6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthenticationService())
            .environmentObject(BLEManager())
    }
}
