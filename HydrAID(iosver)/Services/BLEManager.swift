//
//  BLEManager.swift
//  HydrAID(iosver)
//
//  Updated on 2025.04.06.
//
import Foundation
import CoreBluetooth
import Combine

// Notification names for BLE events
extension Notification.Name {
    static let newBLEMessageReceived = Notification.Name("newBLEMessageReceived")
    static let bleConnectionChanged = Notification.Name("bleConnectionChanged")
}

class BLEManager: NSObject, ObservableObject {
    // Published properties for SwiftUI to observe
    @Published var isScanning = false
    @Published var connectedDevice: CBPeripheral?
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var lastMessage: String = ""
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var deviceBatteryLevel: Int = 100
    
    // Connection status enum
    enum ConnectionStatus {
        case disconnected
        case scanning
        case connecting
        case connected
        case failed(String)
    }
    
    // CoreBluetooth managers
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    
    // Service and characteristic UUIDs for ESP32
    private let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    private let rxCharacteristicUUID = CBUUID(string: "87654321-4321-6789-4321-abcdef987654") // Send data to ESP32
    private let txCharacteristicUUID = CBUUID(string: "56789abc-1234-5678-1234-abcdef987654") // Receive data from ESP32
    
    // Keep track of both characteristics
    private var rxCharacteristic: CBCharacteristic?
    private var txCharacteristic: CBCharacteristic?
    
    // Reconnection properties
    private var shouldAutoReconnect = false
    private var reconnectTimer: Timer?
    private var lastConnectedDeviceIdentifier: UUID?
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Basic BLE Operations
    
    // Start scanning for ESP32 devices
    func startScanning() {
        if centralManager.state == .poweredOn {
            self.isScanning = true
            self.connectionStatus = .scanning
            self.discoveredDevices = []
            
            // Option 1: Scan for specific service UUID if we know it
            // centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
            
            // Option 2: Scan for all BLE devices
            centralManager.scanForPeripherals(withServices: nil, options: nil)
            
            // Time out after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if self?.isScanning == true {
                    self?.stopScanning()
                }
            }
        } else {
            self.connectionStatus = .failed("Bluetooth is not powered on")
        }
    }
    
    // Stop scanning
    func stopScanning() {
        self.isScanning = false
        centralManager.stopScan()
        
        if self.connectedDevice == nil {
            self.connectionStatus = .disconnected
        }
    }
    
    // Connect to a specific device
    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        self.connectionStatus = .connecting
        centralManager.connect(peripheral, options: nil)
        
        // Store this device identifier for auto-reconnect
        self.lastConnectedDeviceIdentifier = peripheral.identifier
    }
    
    // Auto reconnect to last known device
    func reconnectToLastDevice() {
        guard let identifier = lastConnectedDeviceIdentifier else { return }
        
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [identifier])
        if let peripheral = peripherals.first {
            connect(to: peripheral)
        } else {
            // If peripheral isn't immediately available, start scanning
            startScanning()
        }
    }
    
    // Toggle auto reconnect
    func setAutoReconnect(_ enabled: Bool) {
        self.shouldAutoReconnect = enabled
    }
    
    // Disconnect from the current device
    func disconnect() {
        if let peripheral = self.peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // Send data to ESP32
    func sendData(_ data: Data) {
        guard let peripheral = self.peripheral,
              let rxCharacteristic = self.rxCharacteristic else {
            print("Cannot send data, no connected device or RX characteristic")
            return
        }
        
        // Write data to the RX characteristic (sending to ESP32)
        peripheral.writeValue(data, for: rxCharacteristic, type: .withResponse)
    }
    
    // Helper to send string data
    func sendMessage(_ message: String) {
        if let data = message.data(using: .utf8) {
            sendData(data)
        }
    }
    
    // Helper function to clean up the connection
    private func cleanup() {
        rxCharacteristic = nil
        txCharacteristic = nil
        
        if shouldAutoReconnect {
            // Set up a timer to attempt reconnection
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.reconnectToLastDevice()
            }
        }
    }
    
    // MARK: - ESP32 Specific Commands
    
    // Process incoming message from the ESP32 device
    func processIncomingMessage(_ message: String) {
        self.lastMessage = message
        
        // Post notification so other components can react to new data
        NotificationCenter.default.post(
            name: .newBLEMessageReceived,
            object: message
        )
        
        print("Received from device: \(message)")
    }
    
    // Request current sensor readings from the device
    func requestCurrentReadings() {
        let requestCommand = "{\"command\":\"get_readings\"}"
        self.sendMessage(requestCommand)
    }
    
    // Send a command to reset the device measurements
    func resetDeviceMeasurements() {
        let resetCommand = "{\"command\":\"reset_measurements\"}"
        self.sendMessage(resetCommand)
    }
    
    // Send calibration commands
    func calibrateWaterSensor(emptyWeight: Double, fullWeight: Double) {
        let calibrationCommand = """
        {
            "command": "calibrate",
            "sensor": "water",
            "parameters": {
                "empty_weight": \(emptyWeight),
                "full_weight": \(fullWeight)
            }
        }
        """
        self.sendMessage(calibrationCommand)
    }
    
    // Calibrate sugar sensor
    func calibrateSugarSensor(referenceValue: Double) {
        let calibrationCommand = """
        {
            "command": "calibrate",
            "sensor": "sugar",
            "parameters": {
                "reference_value": \(referenceValue)
            }
        }
        """
        self.sendMessage(calibrationCommand)
    }
    
    // Send the optimal levels to the device
    func updateOptimalLevels(waterLiters: Double, sugarGrams: Double) {
        let updateCommand = """
        {
            "update": {
                "water": {
                    "max": \(waterLiters * 1000)
                },
                "sugar": {
                    "max": \(sugarGrams)
                }
            }
        }
        """
        self.sendMessage(updateCommand)
    }
    
    // Get device battery level
    func requestBatteryLevel() {
        let batteryCommand = "{\"command\":\"get_battery\"}"
        self.sendMessage(batteryCommand)
    }
    
    // Get device information
    func requestDeviceInfo() {
        let infoCommand = "{\"command\":\"get_info\"}"
        self.sendMessage(infoCommand)
    }
    
    // Start continuous monitoring mode
    func startContinuousMonitoring(intervalSeconds: Int = 5) {
        let monitorCommand = """
        {
            "command": "start_monitoring",
            "interval": \(intervalSeconds)
        }
        """
        self.sendMessage(monitorCommand)
    }
    
    // Stop continuous monitoring mode
    func stopContinuousMonitoring() {
        let stopCommand = "{\"command\":\"stop_monitoring\"}"
        self.sendMessage(stopCommand)
    }
    
    // Parse battery information from device response
    private func parseBatteryInfo(from message: String) {
        do {
            if let data = message.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let battery = json["battery"] as? Int {
                self.deviceBatteryLevel = battery
            }
        } catch {
            print("Error parsing battery info: \(error)")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    // Called when the central manager's state updates
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            // If auto-reconnect is enabled and we had a previous connection
            if shouldAutoReconnect && lastConnectedDeviceIdentifier != nil {
                reconnectToLastDevice()
            }
            
        case .poweredOff:
            print("Bluetooth is powered off")
            connectionStatus = .failed("Bluetooth is powered off")
            
        case .resetting:
            print("Bluetooth is resetting")
            connectionStatus = .failed("Bluetooth is resetting")
            
        case .unauthorized:
            print("Bluetooth is unauthorized")
            connectionStatus = .failed("Bluetooth access is unauthorized")
            
        case .unsupported:
            print("Bluetooth is unsupported")
            connectionStatus = .failed("Bluetooth is unsupported on this device")
            
        case .unknown:
            print("Bluetooth state is unknown")
            connectionStatus = .failed("Bluetooth state is unknown")
            
        @unknown default:
            print("Unknown Bluetooth state")
            connectionStatus = .failed("Unknown Bluetooth state")
        }
    }
    
    // Called when a peripheral is discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            // Filter out devices with empty names
            if let name = peripheral.name, !name.isEmpty {
                self.discoveredDevices.append(peripheral)
            }
            
            // If auto-reconnect is enabled and this is our last device
            if shouldAutoReconnect,
               let lastID = lastConnectedDeviceIdentifier,
               peripheral.identifier == lastID {
                stopScanning()
                connect(to: peripheral)
            }
        }
    }
    
    // Called when a connection to a peripheral succeeds
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.connectedDevice = peripheral
        self.connectionStatus = .connected
        peripheral.discoverServices([serviceUUID])
        
        // Post a notification about the connection change
        NotificationCenter.default.post(
            name: .bleConnectionChanged,
            object: true
        )
    }
    
    // Called when a connection attempt fails
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.connectedDevice = nil
        self.connectionStatus = .failed(error?.localizedDescription ?? "Failed to connect")
        cleanup()
        
        // Post a notification about the connection change
        NotificationCenter.default.post(
            name: .bleConnectionChanged,
            object: false
        )
    }
    
    // Called when disconnection occurs
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.connectedDevice = nil
        self.connectionStatus = .disconnected
        cleanup()
        
        // Post a notification about the connection change
        NotificationCenter.default.post(
            name: .bleConnectionChanged,
            object: false
        )
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    // Called when services are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    // Called when characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            if characteristic.uuid == rxCharacteristicUUID {
                // Found the RX characteristic for sending data to ESP32
                self.rxCharacteristic = characteristic
                print("Found RX characteristic")
            }
            else if characteristic.uuid == txCharacteristicUUID {
                // Found the TX characteristic for receiving data from ESP32
                self.txCharacteristic = characteristic
                print("Found TX characteristic")
                
                // Enable notifications for the TX characteristic to receive data
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
        
        // Request initial device info once connected
        if self.rxCharacteristic != nil && self.txCharacteristic != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.requestDeviceInfo()
                self.requestBatteryLevel()
                self.requestCurrentReadings()
            }
        }
    }
    
    // Called when characteristic value updates
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating value: \(error!.localizedDescription)")
            return
        }
        
        if let data = characteristic.value, let message = String(data: data, encoding: .utf8) {
            // Process the incoming message
            processIncomingMessage(message)
            
            // Check if it contains battery info
            if message.contains("battery") {
                parseBatteryInfo(from: message)
            }
        }
    }
    
    // Called when the peripheral responds to a write request
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic: \(error.localizedDescription)")
        } else {
            print("Write to characteristic successful")
        }
    }
}
