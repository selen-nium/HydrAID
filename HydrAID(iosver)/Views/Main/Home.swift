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
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .padding(.top)

                            Text("Here's your personalised hydration plan")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Refresh button
                        VStack {
                            Button(action: refreshData) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 24))
                                    .padding(16)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                            Text("Refresh Data")
                                .font(.caption)
                        }                    }
                    .padding(.horizontal, 24)
                    
                    // Hydration tracker
                    HydrationTrackerViewBLE(
                        recommendedIntake: recommendations.water.recommendedLiters,
                        adjustmentFactors: recommendations.water.adjustmentFactors,
                        sensorData: sensorData.hydration
                    )
                    .padding(.horizontal, 24)
                    
                    // Sugar intake tracker
                    SugarIntakeTrackerViewBLE(
                        recommendedLimit: recommendations.sugar.recommendedGrams,
                        adjustmentFactors: recommendations.sugar.adjustmentFactors,
                        sensorData: sensorData.sugar
                    )
                    .padding(.horizontal, 24)
                    
                    // Weather info
                    WeatherInfoView(
                        weatherData: weatherData,
                        isLoading: isLoading,
                        error: errorMessage
                    )
                    .padding(.horizontal, 24)

                    // BLE connection view
                    BLEConnectionView()
                        .padding(.horizontal, 24)
                    
                    // Bottom padding for better scrolling
                    Spacer(minLength: 80)
                }
            }
            .navigationBarTitle("HydrAID", displayMode: .large)
            .navigationBarItems(trailing:
                Button(action: signOut) {
                    HStack {
                        Text("Sign Out")
                            .font(.system(size: 18, weight: .medium))
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .foregroundColor(.red)
                    .padding(8)
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
        print("Weather: \(String(describing: weather.temperature))°C, \(String(describing: weather.humidity))%")
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
        VStack(alignment: .leading, spacing: 20) {
            // Heading with icon for quick visual recognition
            HStack {
                Image(systemName: "drop.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.hydrationBlue)
                Text("Water Intake")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.textPrimary)
            }
            .padding(.bottom, 4)
            
            // Current status with large text
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(sensorData.weight))")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .accessibility(label: Text("\(Int(sensorData.weight)) milliliters consumed"))
                
                Text("ml")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            
            // Goal with larger text
            HStack {
                Text("Daily Goal:")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text("\(Int(recommendedIntake * 1000)) ml")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.hydrationBlue)
            }
            .padding(.bottom, 8)
            
            // Taller progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    Rectangle()
                        .frame(width: geometry.size.width, height: 24)
                        .foregroundColor(Color.hydrationBlue.opacity(0.3))
                        .cornerRadius(12)
                    
                    // Filled progress
                    Rectangle()
                        .frame(width: min(CGFloat(sensorData.percentage / 100) * geometry.size.width, geometry.size.width), height: 24)
                        .foregroundColor(.hydrationBlue)
                        .cornerRadius(12)
                        .animation(.easeInOut(duration: 1), value: sensorData.percentage)
                }
            }
            .frame(height: 24)
            .padding(.bottom, 12)
            
            // Status message in larger text with icon
            HStack(alignment: .center, spacing: 12) {
                statusIcon
                    .font(.system(size: 24))
                
                Text(statusMessage)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
                    .fixedSize(horizontal: false, vertical: true) // Allows proper text wrapping
            }
            .padding(.vertical, 8)
            
            // Adjustment factors in more readable format
            if !adjustmentFactors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why this recommendation:")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    ForEach(adjustmentFactors, id: \.self) { factor in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .font(.system(size: 18))
                                .foregroundColor(.hydrationBlue)
                            Text(factor)
                                .font(.system(size: 18))
                                .foregroundColor(.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibility(hint: Text("Shows your water intake progress"))
    }
    
    // Status messaging
    private var statusMessage: String {
        if sensorData.percentage >= 100 {
            return "Excellent! You've reached your water goal."
        } else if sensorData.percentage >= 75 {
            return "You're doing well! Keep going."
        } else if sensorData.percentage >= 50 {
            return "Halfway there. Remember to drink water regularly."
        } else if sensorData.percentage >= 25 {
            return "Please drink more water soon."
        } else {
            return "Important: You need more water now."
        }
    }
    
    private var statusIcon: some View {
        if sensorData.percentage >= 75 {
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.successGreen)
        } else if sensorData.percentage >= 50 {
            return Image(systemName: "equal.circle.fill")
                .foregroundColor(.hydrationBlue)
        } else {
            return Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.warningRed)
        }
    }
    
    private var statusColor: Color {
        if sensorData.percentage >= 75 {
            return .successGreen
        } else if sensorData.percentage >= 25 {
            return .hydrationBlue
        } else {
            return .warningRed
        }
    }
}

// MARK: - Elderly-Friendly Sugar Tracker

struct SugarIntakeTrackerViewBLE: View {
    let recommendedLimit: Double
    let adjustmentFactors: [String]
    let sensorData: SensorData.SugarData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Heading with icon
            HStack {
                Image(systemName: "cube.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.sugarOrange)
                Text("Sugar Intake")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.textPrimary)
            }
            .padding(.bottom, 4)
            
            // Current status with large text
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(sensorData.weight))")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .accessibility(label: Text("\(Int(sensorData.weight)) grams consumed"))
                
                Text("g")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            
            // Limit with larger text
            HStack {
                Text("Daily Limit:")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text("\(Int(recommendedLimit)) g")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.sugarOrange)
            }
            .padding(.bottom, 8)
            
            // Taller progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    Rectangle()
                        .frame(width: geometry.size.width, height: 24)
                        .foregroundColor(Color.sugarOrange.opacity(0.3))
                        .cornerRadius(12)
                    
                    // Filled progress
                    Rectangle()
                        .frame(width: min(CGFloat(sensorData.percentage / 100) * geometry.size.width, geometry.size.width), height: 24)
                        .foregroundColor(sensorData.percentage > 100 ? .warningRed : .sugarOrange)
                        .cornerRadius(12)
                        .animation(.easeInOut(duration: 1), value: sensorData.percentage)
                }
            }
            .frame(height: 24)
            .padding(.bottom, 12)
            
            // Status message in larger text with icon
            HStack(alignment: .center, spacing: 12) {
                statusIcon
                    .font(.system(size: 24))
                
                Text(statusMessage)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
                    .fixedSize(horizontal: false, vertical: true) // Allows proper text wrapping
            }
            .padding(.vertical, 8)
            
            // Adjustment factors in more readable format
            if !adjustmentFactors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Why this recommendation:")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    ForEach(adjustmentFactors, id: \.self) { factor in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .font(.system(size: 18))
                                .foregroundColor(.sugarOrange)
                            Text(factor)
                                .font(.system(size: 18))
                                .foregroundColor(.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibility(hint: Text("Shows your sugar intake progress"))
    }
    
    // Status messaging
    private var statusMessage: String {
        if sensorData.percentage > 100 {
            return "Important: You've exceeded your sugar limit."
        } else if sensorData.percentage >= 75 {
            return "Be careful: Getting close to your sugar limit."
        } else if sensorData.percentage >= 50 {
            return "Moderate sugar intake so far."
        } else {
            return "Good job! Your sugar intake is healthy."
        }
    }
    
    private var statusIcon: some View {
        if sensorData.percentage > 100 {
            return Image(systemName: "exclamationmark.octagon.fill")
                .foregroundColor(.warningRed)
        } else if sensorData.percentage >= 75 {
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.sugarOrange)
        } else {
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.successGreen)
        }
    }
    
    private var statusColor: Color {
        if sensorData.percentage > 100 {
            return .warningRed
        } else if sensorData.percentage >= 75 {
            return .sugarOrange
        } else {
            return .successGreen
        }
    }
}


struct WeatherInfoView: View {
    let weatherData: WeatherData?
    let isLoading: Bool
    let error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Weather")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.textPrimary)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if let error = error {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("Weather information unavailable")
                        .font(.system(size: 18))
                        .foregroundColor(.textPrimary)
                }
                .padding(.vertical, 20)
            } else if let weather = weatherData {
                HStack(spacing: 40) {
                    // Temperature
                    VStack(spacing: 8) {
                        Image(systemName: temperatureIcon(for: weather.temperature ?? 0))
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                            .padding(.bottom, 4)
                        
                        HStack(alignment: .top, spacing: 4) {
                            Text("\(Int(weather.temperature ?? 0))")
                                .font(.system(size: 42, weight: .bold))
                            Text("°C")
                                .font(.system(size: 24))
                                .padding(.top, 8)
                        }
                        
                        Text("Temperature")
                            .font(.system(size: 18))
                            .foregroundColor(.textPrimary)
                    }
                    
                    // Humidity
                    VStack(spacing: 8) {
                        Image(systemName: "humidity.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                            .padding(.bottom, 4)
                        
                        HStack(alignment: .top, spacing: 4) {
                            Text("\(Int(weather.humidity ?? 0))")
                                .font(.system(size: 42, weight: .bold))
                            Text("%")
                                .font(.system(size: 24))
                                .padding(.top, 8)
                        }
                        
                        Text("Humidity")
                            .font(.system(size: 18))
                            .foregroundColor(.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                
                // Add a weather-based hydration tip
                hydrationTip(for: weather)
                    .padding(.top, 8)
            } else {
                Text("Weather data unavailable")
                    .font(.system(size: 18))
                    .foregroundColor(.textPrimary)
                    .padding(.vertical, 20)
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func temperatureIcon(for temp: Double) -> String {
        if temp > 30 {
            return "thermometer.sun.fill"
        } else if temp > 20 {
            return "thermometer.medium"
        } else {
            return "thermometer.low"
        }
    }
    
    private func hydrationTip(for weather: WeatherData) -> some View {
        let temp = weather.temperature ?? 20
        let humidity = weather.humidity ?? 50
        
        var tipText = ""
        var iconName = ""
        
        if temp > 28 {
            tipText = "Hot day! Remember to drink water more frequently."
            iconName = "exclamationmark.triangle.fill"
        } else if temp > 22 && humidity < 40 {
            tipText = "Dry air today. You may need extra hydration."
            iconName = "drop.degreesign"
        } else if humidity > 70 {
            tipText = "Humid day. Stay hydrated even if you don't feel thirsty."
            iconName = "drop.fill"
        } else {
            tipText = "Remember to drink water regularly throughout the day."
            iconName = "heart.fill"
        }
        
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            Text(tipText)
                .font(.system(size: 18))
                .foregroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Elderly-Friendly UI Components

// A simple extension for our custom colors
extension Color {
    static let hydrationBlue = Color(red: 0.0, green: 0.4, blue: 0.9) // Stronger blue
    static let sugarOrange = Color(red: 0.95, green: 0.5, blue: 0.0) // Distinct orange
    static let warningRed = Color(red: 0.9, green: 0.2, blue: 0.2)   // Brighter red
    static let successGreen = Color(red: 0.0, green: 0.7, blue: 0.3) // Brighter green
    static let cardBackground = Color(UIColor.systemBackground)
    static let textPrimary = Color.primary
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthenticationService())
            .environmentObject(BLEManager())
    }
}
