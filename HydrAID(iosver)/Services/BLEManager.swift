//
//  BLEManager.swift
//  HydrAID(iosver)
//
//  Created by selen on 2025.04.02.
//
import Foundation
import CoreBluetooth
import Combine

class BLEManager: NSObject, ObservableObject {
    // Published properties for SwiftUI to observe
    @Published var isScanning = false
    @Published var connectedDevice: CBPeripheral?
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var lastMessage: String = ""
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
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // Start scanning for ESP32 devices
    func startScanning() {
        if centralManager.state == .poweredOn {
            self.isScanning = true
            self.discoveredDevices = []
            // Start scanning for devices with the specific service UUID
//            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
            
            // scan for all BLE devices
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    // Stop scanning
    func stopScanning() {
        self.isScanning = false
        centralManager.stopScan()
    }
    
    // Connect to a specific device
    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
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
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    // Called when the central manager's state updates
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
        case .resetting:
            print("Bluetooth is resetting")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }
    
    // Called when a peripheral is discovered
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            self.discoveredDevices.append(peripheral)
        }
    }
    
    // Called when a connection to a peripheral succeeds
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.connectedDevice = peripheral
        peripheral.discoverServices([serviceUUID])
    }
    
    // Called when disconnection occurs
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.connectedDevice = nil
        self.rxCharacteristic = nil
        self.txCharacteristic = nil
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
    }
    
    // Called when characteristic value updates
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating value: \(error!.localizedDescription)")
            return
        }
        
        if let data = characteristic.value, let message = String(data: data, encoding: .utf8) {
            self.lastMessage = message
        }
    }
}
