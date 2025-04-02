//
//  Home.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//

import SwiftUI

struct Home: View {
    @EnvironmentObject var bleManager: BLEManager
    @State private var messageToSend: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection status
                HStack {
                    Circle()
                        .fill(bleManager.connectedDevice != nil ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(bleManager.connectedDevice != nil ? "Connected to \(bleManager.connectedDevice?.name ?? "Device")" : "Disconnected")
                        .font(.headline)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Scan button
                Button(bleManager.isScanning ? "Stop Scanning" : "Scan for Devices") {
                    if bleManager.isScanning {
                        bleManager.stopScanning()
                    } else {
                        bleManager.startScanning()
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                // Device list
                if !bleManager.discoveredDevices.isEmpty {
                    Text("Discovered Devices:")
                        .font(.headline)
                        .padding(.top)
                    
                    List {
                        ForEach(bleManager.discoveredDevices, id: \.identifier) { device in
                            Button(action: {
                                bleManager.connect(to: device)
                                bleManager.stopScanning()
                            }) {
                                HStack {
                                    Text(device.name ?? "Unknown Device")
                                    Spacer()
                                    Image(systemName: "bluetooth")
                                }
                            }
                            .disabled(bleManager.connectedDevice != nil)
                        }
                    }
                    .frame(height: 200)
                }
                
                // Controls for connected device
                if bleManager.connectedDevice != nil {
                    VStack(spacing: 12) {
                        Text("Send Message to ESP32:")
                            .font(.headline)
                        
                        TextField("Message", text: $messageToSend)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        Button("Send") {
                            bleManager.sendMessage(messageToSend)
                            messageToSend = "" // Clear after sending
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(messageToSend.isEmpty)
                        
                        Button("Disconnect") {
                            bleManager.disconnect()
                        }
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Received messages
                if !bleManager.lastMessage.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Last Message Received:")
                            .font(.headline)
                        
                        Text(bleManager.lastMessage)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("ESP32 BLE Test")
        }
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        Home()
            .environmentObject(BLEManager())
    }
}
