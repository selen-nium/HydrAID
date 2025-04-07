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
        
        // Explicitly load profile data first
        loadProfileData()
        
        // We'll set a fallback name from Auth just in case profile data isn't loaded yet
        if let displayName = user.displayName, !displayName.isEmpty {
            userName = displayName
        } else if let email = user.email, !email.isEmpty {
            userName = email.components(separatedBy: "@").first ?? "User"
        }
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
            
            if !profile.name.isEmpty {
                self.userName = profile.name
            }
            
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
                if let weight = hydration["weight"] as? Double,
                   let max = hydration["max"] as? Double {
                    
                    // Calculate percentage correctly as (current/goal)*100
                    let percentage = min((weight / max) * 100, 100)
                    
                    self.sensorData.hydration = SensorData.HydrationData(
                        percentage: percentage,
                        weight: weight,
                        max: max
                    )
                }
                
                // Update sugar data
                if let weight = sugar["weight"] as? Double,
                   let max = sugar["max"] as? Double {
                    
                    // Calculate percentage correctly as (current/limit)*100
                    // This will exceed 100% when over the limit
                    let percentage = (weight / max) * 100
                    
                    self.sensorData.sugar = SensorData.SugarData(
                        percentage: percentage,
                        weight: weight,
                        max: max
                    )
                }
                
                print("Updated sensor data: Hydration: \(self.sensorData.hydration.weight)ml (\(self.sensorData.hydration.percentage)%), Sugar: \(self.sensorData.sugar.weight)g (\(self.sensorData.sugar.percentage)%)")
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
        
        // Also ensure your SensorData model is set up with the right max values
        sensorData.hydration.max = recommendations.water.recommendedLiters * 1000
        sensorData.sugar.max = recommendations.sugar.recommendedGrams
        
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
            .padding(.bottom, 8)
            
            // Visual Water Level Indicator
            HStack(alignment: .center, spacing: 20) {
                // Circular progress indicator with water glass metaphor
                ZStack {
                    // Outer circle background
                    Circle()
                        .stroke(Color.hydrationBlue.opacity(0.2), lineWidth: 12)
                        .frame(width: 150, height: 150)
                    
                    // Progress arc
                    Circle()
                        .trim(from: 0, to: CGFloat(min(sensorData.percentage / 100, 1.0)))
                        .stroke(Color.hydrationBlue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1), value: sensorData.percentage)
                    
                    // Water glass icon in the middle
                    VStack(spacing: 5) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.hydrationBlue)
                        
                        Text("\(Int(sensorData.percentage))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.textPrimary)
                    }
                }
                .padding(12)
                
                // Text information
                VStack(alignment: .leading, spacing: 12) {
                    // Current consumption
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            // Container for number with right alignment
                            Text("\(Int(sensorData.weight))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.textPrimary)
                                .frame(minWidth: 60, alignment: .trailing)
                                .lineLimit(1)
                            
                            // Unit with consistent spacing
                            Text("ml")
                                .font(.system(size: 22))
                                .foregroundColor(.textPrimary)
                                .fixedSize()
                        }
                    }
                    
                    // Goal consumption
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Goal")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            // Container for number with right alignment
                            Text("\(Int(recommendedIntake * 1000))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.hydrationBlue)
                                .frame(minWidth: 60, alignment: .trailing)
                                .lineLimit(1)
                            
                            // Unit with consistent spacing
                            Text("ml")
                                .font(.system(size: 20))
                                .foregroundColor(.hydrationBlue)
                                .fixedSize()
                        }
                    }
                    
                    // Remaining
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Remaining")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            let remaining = max(0, (recommendedIntake * 1000) - sensorData.weight)
                            
                            // Container for number with right alignment
                            Text("\(Int(remaining))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(remaining > 0 ? .textPrimary : .successGreen)
                                .frame(minWidth: 60, alignment: .trailing)
                                .lineLimit(1)
                            
                            // Unit with consistent spacing
                            Text("ml")
                                .font(.system(size: 20))
                                .foregroundColor(remaining > 0 ? .textPrimary : .successGreen)
                                .fixedSize()
                        }
                    }
                }
                .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            // Removed water bottle visualization
            
            // Status message in larger text with icon
            HStack(alignment: .center, spacing: 12) {
                statusIcon
                    .font(.system(size: 24))
                
                Text(statusMessage)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            
            // Using the dropdown component for adjustment factors
            if !adjustmentFactors.isEmpty {
                DropdownSection(title: "Why this recommendation", accentColor: .hydrationBlue) {
                    VStack(alignment: .leading, spacing: 12) {
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
                }
            }
            
            // Quick Hydration Tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Tips")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.hydrationBlue)
                    Text("Drink a glass of water with each meal and between meals.")
                        .font(.system(size: 16))
                        .foregroundColor(.textPrimary)
                }
                .padding(.vertical, 2)
            }
            .padding(.top, 8)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(Color.hydrationBlue.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // Water bottle visualization removed
    
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

// Completely revised gauge implementation
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
            .padding(.bottom, 8)
            
            // New simplified visualization with horizontal bar and values
            VStack(spacing: 24) {
                // Current sugar level display
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(sensorData.weight))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(statusColor)
                                .fixedSize()
                            
                            Text("g")
                                .font(.system(size: 22))
                                .foregroundColor(statusColor)
                                .fixedSize()
                        }
                    }
                    
                    Spacer()
                    
                    // Circular percentage indicator
                    ZStack {
                        Circle()
                            .stroke(statusColor.opacity(0.3), lineWidth: 10)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(min(sensorData.percentage / 100, 1.0)))
                            .stroke(statusColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1), value: sensorData.percentage)
                        
                        VStack(spacing: 0) {
                            Text("\(Int(sensorData.percentage))")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(statusColor)
                            
                            Text("%")
                                .font(.system(size: 16))
                                .foregroundColor(statusColor)
                        }
                    }
                }
                .padding(.bottom, 8)
                
                // Sugar level bar visualization
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Daily Limit: \(Int(recommendedLimit))g")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text("Remaining: \(Int(max(0, recommendedLimit - sensorData.weight)))g")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(statusColor)
                    }
                    
                    // Sugar bar with segments
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background segments
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.successGreen.opacity(0.3))
                                    .frame(width: geometry.size.width * 0.5)
                                
                                Rectangle()
                                    .fill(Color.yellow.opacity(0.3))
                                    .frame(width: geometry.size.width * 0.25)
                                
                                Rectangle()
                                    .fill(Color.sugarOrange.opacity(0.3))
                                    .frame(width: geometry.size.width * 0.25)
                            }
                            .frame(height: 24)
                            .cornerRadius(12)
                            
                            // Filled portion (capped at width of bar for display)
                            Rectangle()
                                .fill(filledBarGradient)
                                .frame(width: min(CGFloat(sensorData.percentage / 100) * geometry.size.width, geometry.size.width), height: 24)
                                .cornerRadius(12)
                                .animation(.easeInOut(duration: 1), value: sensorData.percentage)
                            
                            // Add an indicator for exceeding limit if over 100%
                            if sensorData.percentage > 100 {
                                HStack {
                                    Spacer()
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20))
                                        .padding(.trailing, 8)
                                }
                                .frame(width: geometry.size.width, height: 24)
                            }
                        }
                    }
                    .frame(height: 24)
                    
                    // Labels for the segments
                    HStack(spacing: 0) {
                        Text("Safe")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.successGreen)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("Moderate")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text("Limit")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.sugarOrange)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // Status message in larger text with icon
            HStack(alignment: .center, spacing: 12) {
                statusIcon
                    .font(.system(size: 24))
                
                Text(statusMessage)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(statusColor.opacity(0.1))
            .cornerRadius(12)
            
            // Using the dropdown component for adjustment factors
            if !adjustmentFactors.isEmpty {
                DropdownSection(title: "Why this recommendation", accentColor: .sugarOrange) {
                    VStack(alignment: .leading, spacing: 12) {
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
                }
            }
            
            // Quick Sugar Tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Health Tip")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.warningRed)
                    Text("Choose water, tea or coffee without sugar to reduce your daily sugar intake.")
                        .font(.system(size: 16))
                        .foregroundColor(.textPrimary)
                }
                .padding(.vertical, 2)
            }
            .padding(.top, 8)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(Color.sugarOrange.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // Gradient for the filled bar
    private var filledBarGradient: LinearGradient {
       if sensorData.percentage > 100 {
           // Use warning red for over limit
           return LinearGradient(
               gradient: Gradient(colors: [.sugarOrange, .warningRed]),
               startPoint: .leading,
               endPoint: .trailing
           )
       } else if sensorData.percentage > 75 {
           return LinearGradient(
               gradient: Gradient(colors: [.yellow, .sugarOrange]),
               startPoint: .leading,
               endPoint: .trailing
           )
       } else if sensorData.percentage > 50 {
           return LinearGradient(
               gradient: Gradient(colors: [.successGreen, .yellow]),
               startPoint: .leading,
               endPoint: .trailing
           )
       } else {
           return LinearGradient(
               gradient: Gradient(colors: [.successGreen]),
               startPoint: .leading,
               endPoint: .trailing
           )
       }
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
        } else if sensorData.percentage >= 50 {
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
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
        } else if sensorData.percentage >= 50 {
            return .yellow
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

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        
        return path
    }
}

// Triangle shape for the marker
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}
