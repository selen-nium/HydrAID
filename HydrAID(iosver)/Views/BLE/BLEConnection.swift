import SwiftUI
import CoreBluetooth
import FirebaseAuth
import FirebaseFirestore

// Extension to add our specific notification
extension Notification.Name {
    static let newDeviceDiscovered = Notification.Name("newDeviceDiscovered")
}

// Extension for BLEManager to add HydrationTracker-specific functionality
extension BLEManager {
    func startScanningForDevice(named targetName: String) {
        // Start scanning as normal
        startScanning()
        
        // Remove existing observers to avoid duplicates
        NotificationCenter.default.removeObserver(self, name: .bleConnectionChanged, object: nil)
        
        // Add a check for the target device in the discovered devices array
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // If already connected or not scanning, stop timer
            if self.connectionStatus == .connected || !self.isScanning {
                timer.invalidate()
                return
            }
            
            // Look for device with target name
            if let hydrationTracker = self.discoveredDevices.first(where: {
                $0.name?.contains(targetName) ?? false
            }) {
                // Found target device, connect to it
                self.connect(to: hydrationTracker)
                timer.invalidate()
                self.stopScanning()
            }
        }
    }
}

struct BLEConnectionView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var isSearching = false
    @State private var profileData: ProfileData? = nil
    @State private var weatherData: WeatherData? = nil
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // Weather service for fetching current conditions
    private let weatherService = WeatherService()
    
    // Fixed device name for elderly users
    private let deviceName = "HydrationTracker"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with device icon
            HStack {
                Image(systemName: "waterbottle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(connectionStatusColor)
                
                Text("Your HydrAID Tumbler")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            // Status card with clear information
            HStack(spacing: 16) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(connectionStatusColor.opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    if bleManager.connectionStatus == .scanning || bleManager.connectionStatus == .connecting {
                        // Show spinning indicator for active states
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: connectionStatusColor))
                    } else {
                        // Show static icon for stable states
                        Image(systemName: statusIcon)
                            .font(.system(size: 28))
                            .foregroundColor(connectionStatusColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(statusTitle)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(statusMessage)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // Connection button - single action for connecting/disconnecting
            Button(action: handleMainAction) {
                HStack {
                    Image(systemName: actionButtonIcon)
                        .font(.system(size: 20))
                    Text(actionButtonText)
                        .font(.system(size: 20, weight: .medium))
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(actionButtonColor)
                .cornerRadius(12)
            }
            .disabled(bleManager.connectionStatus == .connecting || bleManager.connectionStatus == .scanning)
            .opacity(bleManager.connectionStatus == .connecting || bleManager.connectionStatus == .scanning ? 0.7 : 1)
            
            // Only show device info when connected
            if bleManager.connectionStatus == .connected {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Battery level
                    if bleManager.deviceBatteryLevel > 0 {
                        HStack(spacing: 12) {
                            // Battery icon
                            Image(systemName: batteryIcon)
                                .font(.system(size: 24))
                                .foregroundColor(batteryColor)
                            
                            // Battery percentage
                            Text("\(bleManager.deviceBatteryLevel)% Battery")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(batteryColor)
                            
                            Spacer()
                            
                            // Battery indicator
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .frame(width: 80, height: 16)
                                    .opacity(0.3)
                                    .foregroundColor(.gray)
                                    .cornerRadius(8)
                                
                                Rectangle()
                                    .frame(width: 80 * CGFloat(bleManager.deviceBatteryLevel) / 100.0, height: 16)
                                    .foregroundColor(batteryColor)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Refresh data button - clear single action
                    Button(action: {
                        // Request fresh readings from the device
                        bleManager.requestCurrentReadings()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                            Text("Update Readings")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    // NEW BUTTON: Update Optimal Intake Values
                    Button(action: updateOptimalIntakes) {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 20))
                            Text("Update Optimal Intake Values")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                    
                    // NEW BUTTON: Reset Device
                    Button(action: sendResetCommand) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 20))
                            Text("Reset Device")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.orange)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    // new tare button
                    Button(action: sendTareCommand) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                            Text("Tare Scale")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.orange)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(24)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            // Auto-connect on appear if not already connected
            if bleManager.connectionStatus == .disconnected && !isSearching {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    startSearching()
                }
            }
            
            // Fetch profile and weather data when view appears
            fetchProfileData()
            fetchWeatherData()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Helper Properties
    
    private var connectionStatusColor: Color {
        switch bleManager.connectionStatus {
        case .connected:
            return .green
        case .connecting, .scanning:
            return .blue
        case .disconnected:
            return .gray
        case .failed:
            return .red
        }
    }
    
    private var statusIcon: String {
        switch bleManager.connectionStatus {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting, .scanning:
            return "arrow.clockwise"
        case .disconnected:
            return "wifi.slash"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var statusTitle: String {
        switch bleManager.connectionStatus {
        case .connected:
            return "Device Connected"
        case .connecting:
            return "Connecting..."
        case .scanning:
            return "Searching..."
        case .disconnected:
            return "Not Connected"
        case .failed:
            return "Connection Failed"
        }
    }
    
    private var statusMessage: String {
        switch bleManager.connectionStatus {
        case .connected:
            return "Your HydrAID Tumbler is connected and sending data."
        case .connecting:
            return "Connecting to your HydrAID Tumbler..."
        case .scanning:
            return "Looking for your HydrAID Tumbler. Make sure it's turned on and nearby."
        case .disconnected:
            return "Press the button below to connect to your HydrAID Tumbler."
        case .failed(let message):
            return "Error: \(message). Try again."
        }
    }
    
    private var actionButtonText: String {
        switch bleManager.connectionStatus {
        case .connected:
            return "Disconnect Device"
        case .connecting, .scanning:
            return "Searching..."
        case .disconnected, .failed:
            return "Connect to HydrAID Tumbler"
        }
    }
    
    private var actionButtonIcon: String {
        switch bleManager.connectionStatus {
        case .connected:
            return "xmark.circle.fill"
        case .connecting, .scanning:
            return "arrow.clockwise"
        case .disconnected, .failed:
            return "link.circle.fill"
        }
    }
    
    private var actionButtonColor: Color {
        switch bleManager.connectionStatus {
        case .connected:
            return .red
        case .connecting, .scanning, .disconnected, .failed:
            return .blue
        }
    }
    
    private var batteryColor: Color {
        if bleManager.deviceBatteryLevel > 70 {
            return .green
        } else if bleManager.deviceBatteryLevel > 30 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var batteryIcon: String {
        if bleManager.deviceBatteryLevel > 70 {
            return "battery.100"
        } else if bleManager.deviceBatteryLevel > 30 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }
    
    // MARK: - Actions
    
    private func handleMainAction() {
        switch bleManager.connectionStatus {
        case .connected:
            bleManager.disconnect()
        case .disconnected, .failed:
            startSearching()
        default:
            // Do nothing during connecting/scanning states
            break
        }
    }
    
    private func startSearching() {
        isSearching = true
        
        // Use the extension method to scan specifically for the HydrationTracker
        bleManager.startScanningForDevice(named: deviceName)
        
        // Auto-stop searching after 30 seconds if nothing found
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if bleManager.connectionStatus != .connected {
                bleManager.stopScanning()
                isSearching = false
            }
        }
    }
    
    // NEW METHOD: Send reset command to device
    private func sendResetCommand() {
        bleManager.sendResetCommand()
        
        // Show confirmation to user
        self.alertTitle = "Reset Sent"
        self.alertMessage = "Reset command has been sent to your HydrAID Tumbler."
        self.showAlert = true
    }
    
    // NEW METHOD: Send tare command to device
    private func sendTareCommand() {
        bleManager.sendTareCommand()
        
        // Show confirmation to user
        self.alertTitle = "Tare Sent"
        self.alertMessage = "Tare command has been sent to your HydrAID Tumbler."
        self.showAlert = true
    }

    
    // Fetch profile data from Firebase
    private func fetchProfileData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            alertTitle = "Error"
            alertMessage = "User not authenticated"
            showAlert = true
            return
        }
        
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            isLoading = false
            
            if let error = error {
                alertTitle = "Error"
                alertMessage = "Failed to load profile: \(error.localizedDescription)"
                showAlert = true
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                alertTitle = "Error"
                alertMessage = "Profile data not found"
                showAlert = true
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
            
            self.profileData = profile
        }
    }
    
    // Fetch current weather data
    private func fetchWeatherData() {
        Task {
            do {
                let weather = try await weatherService.getLatestWeatherData()
                DispatchQueue.main.async {
                    self.weatherData = weather
                }
            } catch {
                DispatchQueue.main.async {
                    print("Weather fetch error: \(error)")
                    // Silently fail for weather - not critical
                }
            }
        }
    }
    
    // Update optimal intake values and send to device
    private func updateOptimalIntakes() {
        isLoading = true
        
        // First ensure we have the latest profile data
        fetchProfileData()
        
        // Also get fresh weather data
        fetchWeatherData()
        
        // Add small delay to ensure data is fetched
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Create default profile data if not available
            let profile = self.profileData ?? self.createDefaultProfileData()
            
            // Calculate water intake
            let waterRecommendation = IntakeCalculator.calculateWaterIntake(
                weatherData: self.weatherData,
                profileData: profile
            )
            
            // Calculate sugar intake
            let sugarRecommendation = IntakeCalculator.calculateSugarIntake(
                profileData: profile
            )
            
            // Send the updated values to the device
            self.bleManager.updateOptimalLevels(
                waterLiters: waterRecommendation.recommendedLiters,
                sugarGrams: sugarRecommendation.recommendedGrams
            )
            
            self.isLoading = false
            
            // Show confirmation to user
            self.alertTitle = "Values Updated"
            self.alertMessage = "Optimal intake values have been sent to your HydrAID Tumbler.\n\nWater: \(waterRecommendation.recommendedLiters) liters\nSugar: \(sugarRecommendation.recommendedGrams) grams"
            self.showAlert = true
        }
    }
    
    // Helper function to create default profile data
    private func createDefaultProfileData() -> ProfileData {
        // Create a default profile with reasonable values
        var profile = ProfileData()
        profile.weight = "70" // Default weight in kg
        profile.age = "50"    // Default age
        profile.activityLevel = "Moderately Active"
        profile.healthConditions = []
        profile.medications = []
        return profile
    }
}
