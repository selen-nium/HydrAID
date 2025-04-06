import SwiftUI
import CoreBluetooth

struct BLEConnectionView: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var showDeviceList = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Connection")
                .font(.headline)
            
            // Connection status
            HStack {
                Image(systemName: connectionStatusIcon)
                    .foregroundColor(connectionStatusColor)
                    .frame(width: 24, height: 24)
                
                Text(connectionStatusText)
                    .font(.subheadline)
                
                Spacer()
                
                if bleManager.connectionStatus == .connected {
                    // Disconnect button
                    Button(action: {
                        bleManager.disconnect()
                    }) {
                        Text("Disconnect")
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                } else if bleManager.isScanning {
                    // Cancel scanning button
                    Button(action: {
                        bleManager.stopScanning()
                    }) {
                        Text("Cancel")
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                } else {
                    // Scan button
                    Button(action: {
                        bleManager.startScanning()
                        showDeviceList = true
                    }) {
                        Text("Scan")
                            .font(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            }
            
            // Show discovered devices when scanning
            if showDeviceList && bleManager.isScanning || !bleManager.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Devices:")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    if bleManager.isScanning && bleManager.discoveredDevices.isEmpty {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 4)
                            Text("Scanning...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(bleManager.discoveredDevices, id: \.identifier) { device in
                                Button(action: {
                                    bleManager.connect(to: device)
                                    showDeviceList = false
                                }) {
                                    HStack {
                                        Image(systemName: "wave.3.right")
                                            .foregroundColor(.blue)
                                            .frame(width: 24, height: 24)
                                        
                                        Text(device.name ?? "Unknown Device")
                                            .font(.system(size: 14))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding(.top, 8)
            }
            
            // Device info when connected
            if bleManager.connectionStatus == .connected, let device = bleManager.connectedDevice {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Connected to:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(device.name ?? "Unknown Device")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Battery:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(bleManager.deviceBatteryLevel)%")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        // Battery level indicator
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .frame(width: 50, height: 8)
                                .opacity(0.3)
                                .foregroundColor(.gray)
                            
                            Rectangle()
                                .frame(width: 50 * CGFloat(bleManager.deviceBatteryLevel) / 100.0, height: 8)
                                .foregroundColor(batteryColor)
                        }
                        .cornerRadius(4)
                    }
                    
                    HStack {
                        Button(action: {
                            bleManager.requestCurrentReadings()
                        }) {
                            Text("Refresh Data")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            bleManager.startContinuousMonitoring(intervalSeconds: 10)
                        }) {
                            Text("Start Monitoring")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            bleManager.stopContinuousMonitoring()
                        }) {
                            Text("Stop Monitoring")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            // Auto-start scanning if no device is connected
            if bleManager.connectionStatus == .disconnected && !bleManager.isScanning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    bleManager.startScanning()
                    showDeviceList = true
                }
            }
        }
    }
    
    // Helper computed properties for status display
    private var connectionStatusText: String {
        switch bleManager.connectionStatus {
        case .disconnected:
            return "Disconnected"
        case .scanning:
            return "Scanning..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }
    
    private var connectionStatusIcon: String {
        switch bleManager.connectionStatus {
        case .disconnected:
            return "wifi.slash"
        case .scanning:
            return "wifi.exclamationmark"
        case .connecting:
            return "wifi"
        case .connected:
            return "wifi.circle.fill"
        case .failed:
            return "xmark.circle"
        }
    }
    
    private var connectionStatusColor: Color {
        switch bleManager.connectionStatus {
        case .disconnected:
            return .gray
        case .scanning:
            return .orange
        case .connecting:
            return .blue
        case .connected:
            return .green
        case .failed:
            return .red
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
}

struct BLEConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        BLEConnectionView()
            .environmentObject(BLEManager())
            .padding()
    }
}
