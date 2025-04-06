//
//  Home.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

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
    @State private var profileData: ProfileData? = nil
    @State private var cancellables = Set<AnyCancellable>()
    
//    @Published var profileData: ProfileData? = nil
    private let weatherService = WeatherService()
    
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
            .onChange(of: profileData) { newValue in
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
        errorMessage = nil
        
        do {
            // Fetch weather data
            weatherData = try await weatherService.getLatestWeatherData()
            
            loadUserData()
            calculateRecommendations()
        } catch {
            errorMessage = "Failed to load weather data: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
        
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
        
        // Explicitly load profile data
        loadProfileData()
    }
    
    private func loadWeatherData() {
        Task {
            do {
                weatherData = try await weatherService.getLatestWeatherData()
                
                print("🌈 Weather Data Loaded:")
                print("Temperature: \(weatherData?.temperature ?? 0)°C")
                print("Humidity: \(weatherData?.humidity ?? 0)%")
                
                // Recalculate recommendations if profile data is already loaded
                calculateRecommendations()
                
                isLoading = false
            } catch {
                errorMessage = "Failed to load weather data: \(error.localizedDescription)"
                isLoading = false
                print("❌ Weather Data Load Error: \(error)")
                
                // Even if weather data fails, try to calculate recommendations
                calculateRecommendations()
            }
        }
    }
        
    @MainActor
    private func loadProfileData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { [self] snapshot, error in
            if let error = error {
                print("❌ Error fetching user profile: \(error.localizedDescription)")
                return
            }
            
            guard let data = snapshot?.data() else {
                print("❌ No user data found")
                return
            }
            
            var profile = ProfileData()
            profile.name = data["name"] as? String ?? ""
            profile.gender = data["gender"] as? String ?? ""
            profile.weight = data["weight"] as? String ?? ""
            profile.age = data["age"] as? String ?? ""
            profile.activityLevel = data["activityLevel"] as? String ?? ""
            profile.healthConditions = data["healthConditions"] as? [String] ?? []
            profile.medications = data["medications"] as? [String] ?? []
            
            print("🔍 Loaded Profile Data:")
            print("Name: \(profile.name)")
            print("Weight: \(profile.weight)")
            print("Age: \(profile.age)")
            print("Activity Level: \(profile.activityLevel)")
            print("Health Conditions: \(profile.healthConditions)")
            print("Medications: \(profile.medications)")
            
            // Update profileData and trigger recommendations recalculation
            self.profileData = profile
            self.calculateRecommendations()
        }
    }

    private func calculateRecommendations() {
        guard let profile = profileData else {
            print("❌ Profile data is missing")
            // Reset to default if profile data is incomplete
            recommendations.water = IntakeRecommendations.WaterRecommendation(
                recommendedLiters: 2.5,
                adjustmentFactors: ["Default recommendation"]
            )
            recommendations.sugar = IntakeRecommendations.SugarRecommendation(
                recommendedGrams: 25,
                adjustmentFactors: ["Default recommendation"]
            )
            return
        }
        
        // If weather data is not available, use a default weather object
        let weather = weatherData ?? WeatherData(
            temperature: 25.0,  // Default moderate temperature
            humidity: 50.0,     // Default moderate humidity
            location: "Default",
            timestamp: Date().ISO8601Format(),
            temperatureUnit: "°C",
            humidityUnit: "%"
        )
        
        print("🌞 Calculating Recommendations with:")
        print("Weather: \(weather.temperature)°C, \(weather.humidity)%")
        print("Profile Weight: \(profile.weight)")
        print("Profile Age: \(profile.age)")
        print("Profile Activity: \(profile.activityLevel)")
        
        // Calculate water intake
        recommendations.water = IntakeCalculator.calculateWaterIntake(
            weatherData: weather,
            profileData: profile
        )
        
        // Calculate sugar intake
        recommendations.sugar = IntakeCalculator.calculateSugarIntake(
            profileData: profile
        )
        
        print("💧 Water Recommendation: \(recommendations.water.recommendedLiters) L")
        print("🍬 Sugar Recommendation: \(recommendations.sugar.recommendedGrams) g")
        print("Water Factors: \(recommendations.water.adjustmentFactors)")
        print("Sugar Factors: \(recommendations.sugar.adjustmentFactors)")
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
                            Text("\(Int(weather.temperature ?? 0))")
                                .font(.system(size: 40, weight: .medium))
                            Text("°C")
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
                            Text("\(Int(weather.humidity ?? 0))")
                                .font(.system(size: 40, weight: .medium))
                            Text("%")
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
