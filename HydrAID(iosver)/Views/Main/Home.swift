import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct SensorData {
    var hydration: HydrationData
    var sugar: SugarData
    
    struct HydrationData {
        var percentage: Double
        var weight: Double
        var max: Double
    }
    
    struct SugarData {
        var percentage: Double
        var weight: Double
        var max: Double
    }
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
    @State private var profileData: ProfileData? = nil
    @State private var cancellables = Set<AnyCancellable>()
    @State private var sensorData = SensorData(
        hydration: SensorData.HydrationData(percentage: 0, weight: 0, max: 2500),
        sugar: SensorData.SugarData(percentage: 0, weight: 0, max: 25)
    )
    
    private let weatherService = WeatherService()
    private let dailyUpdateTimer = Timer.publish(every: 86400, on: .main, in: .common).autoconnect()
    
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
                    HydrationTrackerViewBLE(
                        recommendedIntake: recommendations.water.recommendedLiters,
                        adjustmentFactors: recommendations.water.adjustmentFactors,
                        sensorData: sensorData.hydration
                    )
                    .padding(.horizontal)
                    
                    // Sugar intake tracker
                    SugarIntakeTrackerViewBLE(
                        recommendedLimit: recommendations.sugar.recommendedGrams,
                        adjustmentFactors: recommendations.sugar.adjustmentFactors,
                        sensorData: sensorData.sugar
                    )
                    .padding(.horizontal)
                    
                    // Weather info
                    WeatherInfoView(
                        weatherData: weatherData,
                        isLoading: isLoading,
                        error: errorMessage
                    )
                    .padding(.horizontal)

                    // BLE connection view
                    BLEConnectionView()
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
                setupBLENotifications()
                scheduleOptimalIntakeUpdate()
            }
            .onChange(of: profileData) { newValue in
                calculateRecommendations()
                updateOptimalIntakeLevels()
            }
            .onReceive(dailyUpdateTimer) { _ in
                updateOptimalIntakeLevels()
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
            updateOptimalIntakeLevels()
            
            // Request current readings from BLE device
            if bleManager.connectionStatus == .connected {
                bleManager.requestCurrentReadings()
            }
            
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
            self.updateOptimalIntakeLevels()
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
    
    // MARK: - BLE Integration
    
    private func setupBLENotifications() {
        // Listen for BLE messages
        NotificationCenter.default.addObserver(
            forName: .newBLEMessageReceived,
            object: nil,
            queue: .main
        ) { notification in
            if let message = notification.object as? String {
                self.processBLEMessage(message)
            }
        }
        
        // Listen for BLE connection changes
        NotificationCenter.default.addObserver(
            forName: .bleConnectionChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let isConnected = notification.object as? Bool, isConnected {
                // Request current sensor readings when connected
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.bleManager.requestCurrentReadings()
                }
            }
        }
    }
    
    private func processBLEMessage(_ message: String) {
        print("Processing BLE message: \(message)")
        
        do {
            if let data = message.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Check if this is a hydration/sugar reading
                if let hydration = json["hydration"] as? [String: Any],
                   let sugar = json["sugar"] as? [String: Any] {
                    
                    // Update hydration data
                    if let percentage = hydration["percentage"] as? Double,
                       let weight = hydration["weight"] as? Double,
                       let max = hydration["max"] as? Double {
                        
                        self.sensorData.hydration = SensorData.HydrationData(
                            percentage: percentage,
                            weight: weight,
                            max: max
                        )
                    }
                    
                    // Update sugar data
                    if let percentage = sugar["percentage"] as? Double,
                       let weight = sugar["weight"] as? Double,
                       let max = sugar["max"] as? Double {
                        
                        self.sensorData.sugar = SensorData.SugarData(
                            percentage: percentage,
                            weight: weight,
                            max: max
                        )
                    }
                    
                    print("Updated sensor data: Hydration: \(self.sensorData.hydration.weight)ml, Sugar: \(self.sensorData.sugar.weight)g")
                }
            }
        } catch {
            print("Error parsing BLE message: \(error)")
        }
    }
    
    private func updateOptimalIntakeLevels() {
        // Send optimal levels to the ESP32
        bleManager.updateOptimalLevels(
            waterLiters: recommendations.water.recommendedLiters,
            sugarGrams: recommendations.sugar.recommendedGrams
        )
        
        print("🔄 Updated optimal intake levels on ESP32:")
        print("Water: \(recommendations.water.recommendedLiters) L")
        print("Sugar: \(recommendations.sugar.recommendedGrams) g")
    }
    
    private func scheduleOptimalIntakeUpdate() {
        // Create a daily timer to update the device at 23:59
        let now = Date()
        let calendar = Calendar.current
        
        // Set up components for 23:59 today
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 23
        components.minute = 59
        components.second = 0
        
        guard let targetTime = calendar.date(from: components) else {
            print("Failed to create target time for scheduler")
            return
        }
        
        // If it's already past 23:59, schedule for tomorrow
        var scheduledTime = targetTime
        if now > targetTime {
            scheduledTime = calendar.date(byAdding: .day, value: 1, to: targetTime) ?? targetTime
        }
        
        // Calculate seconds until the scheduled time
        let timeInterval = scheduledTime.timeIntervalSince(now)
        
        print("Scheduling optimal intake update at: \(scheduledTime)")
        print("Time until update: \(timeInterval) seconds")
        
        // Schedule the one-time timer
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            // Update the optimal levels
            self.updateOptimalIntakeLevels()
            
            // Schedule for the next day
            self.scheduleOptimalIntakeUpdate()
        }
    }
}

// MARK: - Updated Component Views for BLE Integration

struct HydrationTrackerViewBLE: View {
    let recommendedIntake: Double
    let adjustmentFactors: [String]
    let sensorData: SensorData.HydrationData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hydration Tracker")
                .font(.headline)
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(sensorData.weight)) ml")
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
                            .frame(width: min(CGFloat(sensorData.percentage / 100) * geometry.size.width, geometry.size.width), height: 10)
                            .foregroundColor(.blue)
                            .cornerRadius(5)
                            .animation(.linear, value: sensorData.percentage)
                    }
                }
                .frame(height: 10)
            }
            
            // Status information
            VStack(alignment: .leading, spacing: 6) {
                Text("Current status:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if sensorData.percentage >= 100 {
                    Text("Great job! You've reached your hydration goal.")
                        .font(.callout)
                        .foregroundColor(.green)
                } else if sensorData.percentage >= 75 {
                    Text("You're doing well! Almost at your daily goal.")
                        .font(.callout)
                        .foregroundColor(.green)
                } else if sensorData.percentage >= 50 {
                    Text("Halfway there! Keep drinking water.")
                        .font(.callout)
                        .foregroundColor(.orange)
                } else if sensorData.percentage >= 25 {
                    Text("You need more water. Try to drink more frequently.")
                        .font(.callout)
                        .foregroundColor(.orange)
                } else {
                    Text("You're dehydrated! Please increase your water intake.")
                        .font(.callout)
                        .foregroundColor(.red)
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

struct SugarIntakeTrackerViewBLE: View {
    let recommendedLimit: Double
    let adjustmentFactors: [String]
    let sensorData: SensorData.SugarData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sugar Intake Tracker")
                .font(.headline)
            
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(Int(sensorData.weight)) g")
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
                            .frame(width: min(CGFloat(sensorData.percentage / 100) * geometry.size.width, geometry.size.width), height: 10)
                            .foregroundColor(sensorData.percentage > 100 ? .red : .orange)
                            .cornerRadius(5)
                            .animation(.linear, value: sensorData.percentage)
                    }
                }
                .frame(height: 10)
            }
            
            // Status information
            VStack(alignment: .leading, spacing: 6) {
                Text("Current status:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if sensorData.percentage > 100 {
                    Text("Warning! You've exceeded your recommended sugar limit.")
                        .font(.callout)
                        .foregroundColor(.red)
                } else if sensorData.percentage >= 75 {
                    Text("You're approaching your daily sugar limit.")
                        .font(.callout)
                        .foregroundColor(.orange)
                } else if sensorData.percentage >= 50 {
                    Text("Moderate sugar intake so far today.")
                        .font(.callout)
                        .foregroundColor(.orange)
                } else {
                    Text("Good job! Your sugar intake is within healthy limits.")
                        .font(.callout)
                        .foregroundColor(.green)
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


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthenticationService())
            .environmentObject(BLEManager())
    }
}
