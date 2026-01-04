//
//  G7BluetoothManager.swift
//  Luka
//
//  Adapted from G7SensorKit - Central manager for G7 BLE scanning/connection
//

import CoreBluetooth
import Foundation
import os.log

enum PeripheralConnectionCommand {
    case connect
    case makeActive
    case ignore
}

protocol G7BluetoothManagerDelegate: AnyObject {
    func bluetoothManager(_ manager: G7BluetoothManager, readied peripheralManager: G7PeripheralManager) -> Bool
    func bluetoothManager(_ manager: G7BluetoothManager, readyingFailed peripheralManager: G7PeripheralManager, with error: Error)
    func bluetoothManager(_ manager: G7BluetoothManager, shouldConnectPeripheral peripheral: CBPeripheral) -> PeripheralConnectionCommand
    func bluetoothManager(_ manager: G7BluetoothManager, peripheralManager: G7PeripheralManager, didReceiveControlResponse response: Data)
    func bluetoothManager(_ manager: G7BluetoothManager, didReceiveBackfillResponse response: Data)
    func bluetoothManager(_ manager: G7BluetoothManager, peripheralManager: G7PeripheralManager, didReceiveAuthenticationResponse response: Data)
    func bluetoothManagerScanningStatusDidChange(_ manager: G7BluetoothManager)
    func peripheralDidDisconnect(_ manager: G7BluetoothManager, peripheralManager: G7PeripheralManager, wasRemoteDisconnect: Bool)
}

class G7BluetoothManager: NSObject {
    weak var delegate: G7BluetoothManagerDelegate?

    private let log = Logger(subsystem: "com.kylebashour.Luka", category: "G7BluetoothManager")
    private var centralManager: CBCentralManager! = nil
    private var managedPeripherals: [UUID: G7PeripheralManager] = [:]

    private var activePeripheral: CBPeripheral? {
        return activePeripheralManager?.peripheral
    }

    var activePeripheralIdentifier: UUID? {
        return lockedPeripheralIdentifier.value
    }
    private let lockedPeripheralIdentifier: Locked<UUID?> = Locked(nil)

    private var activePeripheralManager: G7PeripheralManager? {
        didSet {
            oldValue?.delegate = nil
            lockedPeripheralIdentifier.value = activePeripheralManager?.peripheral.identifier
        }
    }

    private let managerQueue = DispatchQueue(label: "com.kylebashour.Luka.bluetoothManagerQueue", qos: .unspecified)

    override init() {
        super.init()
        managerQueue.sync {
            self.centralManager = CBCentralManager(
                delegate: self,
                queue: managerQueue,
                options: [CBCentralManagerOptionRestoreIdentifierKey: "com.kylebashour.Luka.G7"]
            )
        }
    }

    // MARK: - Actions

    func scanForPeripheral() {
        dispatchPrecondition(condition: .notOnQueue(managerQueue))
        managerQueue.sync { managerQueue_scanForPeripheral() }
    }

    func forgetPeripheral() {
        managerQueue.sync { activePeripheralManager = nil }
    }

    func stopScanning() {
        managerQueue.sync { managerQueue_stopScanning() }
    }

    private func managerQueue_stopScanning() {
        if centralManager.isScanning {
            log.debug("Stopping scan")
            centralManager.stopScan()
            delegate?.bluetoothManagerScanningStatusDidChange(self)
        }
    }

    func disconnect() {
        dispatchPrecondition(condition: .notOnQueue(managerQueue))
        managerQueue.sync {
            if centralManager.isScanning {
                log.debug("Stopping scan on disconnect")
                centralManager.stopScan()
                delegate?.bluetoothManagerScanningStatusDidChange(self)
            }
            if let peripheral = activePeripheral {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    private func managerQueue_scanForPeripheral() {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        guard centralManager.state == .poweredOn else { return }

        let currentState = activePeripheral?.state ?? .disconnected
        guard currentState != .connected else { return }

        if let peripheralID = activePeripheralIdentifier,
           let peripheral = centralManager.retrievePeripherals(withIdentifiers: [peripheralID]).first {
            log.debug("Retrieved peripheral \(peripheral.identifier.uuidString)")
            handleDiscoveredPeripheral(peripheral)
        } else {
            for peripheral in centralManager.retrieveConnectedPeripherals(withServices: [
                SensorServiceUUID.advertisement.cbUUID,
                SensorServiceUUID.cgmService.cbUUID
            ]) {
                handleDiscoveredPeripheral(peripheral)
            }
        }

        if activePeripheral == nil {
            log.debug("Scanning for peripherals")
            centralManager.scanForPeripherals(
                withServices: [SensorServiceUUID.advertisement.cbUUID],
                options: nil
            )
            delegate?.bluetoothManagerScanningStatusDidChange(self)
        }
    }

    fileprivate func scanAfterDelay() {
        DispatchQueue.global(qos: .utility).async {
            Thread.sleep(forTimeInterval: 2)
            self.scanForPeripheral()
        }
    }

    // MARK: - Accessors

    var isScanning: Bool {
        dispatchPrecondition(condition: .notOnQueue(managerQueue))
        var result = false
        managerQueue.sync { result = centralManager.isScanning }
        return result
    }

    var isConnected: Bool {
        dispatchPrecondition(condition: .notOnQueue(managerQueue))
        var result = false
        managerQueue.sync { result = activePeripheral?.state == .connected }
        return result
    }

    private func handleDiscoveredPeripheral(_ peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        guard let delegate else { return }

        switch delegate.bluetoothManager(self, shouldConnectPeripheral: peripheral) {
        case .makeActive:
            log.debug("Making peripheral active: \(peripheral.identifier.uuidString)")
            if let peripheralManager = activePeripheralManager {
                peripheralManager.peripheral = peripheral
            } else {
                activePeripheralManager = G7PeripheralManager(
                    peripheral: peripheral,
                    configuration: .dexcomG7,
                    centralManager: centralManager
                )
                activePeripheralManager?.delegate = self
            }
            managedPeripherals[peripheral.identifier] = activePeripheralManager
            centralManager.connect(peripheral)

        case .connect:
            log.debug("Connecting to peripheral: \(peripheral.identifier.uuidString)")
            centralManager.connect(peripheral)
            let peripheralManager = G7PeripheralManager(
                peripheral: peripheral,
                configuration: .dexcomG7,
                centralManager: centralManager
            )
            peripheralManager.delegate = self
            managedPeripherals[peripheral.identifier] = peripheralManager

        case .ignore:
            break
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension G7BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        activePeripheralManager?.centralManagerDidUpdateState(central)
        log.info("centralManagerDidUpdateState: \(central.state.rawValue)")

        switch central.state {
        case .poweredOn:
            managerQueue_scanForPeripheral()
        case .resetting, .poweredOff, .unauthorized, .unknown, .unsupported:
            fallthrough
        @unknown default:
            if central.isScanning {
                log.debug("Stopping scan on central not powered on")
                central.stopScan()
                delegate?.bluetoothManagerScanningStatusDidChange(self)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                log.info("Restoring peripheral from state: \(peripheral.identifier.uuidString)")
                handleDiscoveredPeripheral(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        log.info("didDiscover: \(peripheral.name ?? "unnamed"), rssi: \(RSSI)")
        managerQueue.async { self.handleDiscoveredPeripheral(peripheral) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        log.info("didConnect: \(peripheral.identifier.uuidString)")

        if let peripheralManager = managedPeripherals[peripheral.identifier] {
            peripheralManager.centralManager(central, didConnect: peripheral)

            if let delegate, case .poweredOn = centralManager.state, case .connected = peripheral.state {
                if delegate.bluetoothManager(self, readied: peripheralManager) {
                    managerQueue_stopScanning()
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        log.info("didDisconnectPeripheral: \(peripheral.identifier.uuidString)")

        if let error = error as NSError?, CBError(_nsError: error).code != .peripheralDisconnected {
            log.error("Disconnect error: \(error)")
            if let peripheralManager = activePeripheralManager {
                delegate?.bluetoothManager(self, readyingFailed: peripheralManager, with: error)
            }
        }

        if let peripheralManager = managedPeripherals[peripheral.identifier] {
            let remoteDisconnect: Bool
            if let error = error as NSError?, CBError(_nsError: error).code == .peripheralDisconnected {
                remoteDisconnect = true
            } else {
                remoteDisconnect = false
            }
            delegate?.peripheralDidDisconnect(self, peripheralManager: peripheralManager, wasRemoteDisconnect: remoteDisconnect)
        }

        if peripheral != activePeripheral {
            managedPeripherals.removeValue(forKey: peripheral.identifier)
        }

        scanAfterDelay()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        log.error("didFailToConnect: \(error?.localizedDescription ?? "unknown")")

        if let error, let peripheralManager = activePeripheralManager {
            delegate?.bluetoothManager(self, readyingFailed: peripheralManager, with: error)
        }

        if peripheral != activePeripheral {
            managedPeripherals.removeValue(forKey: peripheral.identifier)
        }

        scanAfterDelay()
    }
}

// MARK: - G7PeripheralManagerDelegate

extension G7BluetoothManager: G7PeripheralManagerDelegate {
    func peripheralManager(_ manager: G7PeripheralManager, didReadRSSI RSSI: NSNumber, error: Error?) {}
    func peripheralManagerDidUpdateName(_ manager: G7PeripheralManager) {}
    func peripheralManagerDidConnect(_ manager: G7PeripheralManager) {}
    func completeConfiguration(for manager: G7PeripheralManager) throws {}

    func peripheralManager(_ manager: G7PeripheralManager, didUpdateValueFor characteristic: CBCharacteristic) {
        guard let value = characteristic.value else { return }

        switch CGMServiceCharacteristicUUID(rawValue: characteristic.uuid.uuidString.uppercased()) {
        case .none, .communication?:
            return
        case .control?:
            delegate?.bluetoothManager(self, peripheralManager: manager, didReceiveControlResponse: value)
        case .backfill?:
            delegate?.bluetoothManager(self, didReceiveBackfillResponse: value)
        case .authentication?:
            delegate?.bluetoothManager(self, peripheralManager: manager, didReceiveAuthenticationResponse: value)
        }
    }
}
