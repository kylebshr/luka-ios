//
//  G7PeripheralManager.swift
//  Luka
//
//  Adapted from G7SensorKit - Manages a single G7 peripheral connection
//

import CoreBluetooth
import Foundation
import os.log

enum PeripheralManagerError: Error {
    case cbPeripheralError(Error)
    case notReady
    case invalidConfiguration
    case timeout
    case unknownCharacteristic
}

protocol G7PeripheralManagerDelegate: AnyObject {
    func peripheralManager(_ manager: G7PeripheralManager, didUpdateValueFor characteristic: CBCharacteristic)
    func peripheralManager(_ manager: G7PeripheralManager, didReadRSSI RSSI: NSNumber, error: Error?)
    func peripheralManagerDidUpdateName(_ manager: G7PeripheralManager)
    func completeConfiguration(for manager: G7PeripheralManager) throws
}

class G7PeripheralManager: NSObject {
    private let log = Logger(subsystem: "com.kylebashour.Luka", category: "G7PeripheralManager")

    var peripheral: CBPeripheral {
        didSet {
            guard oldValue !== peripheral else { return }
            log.error("Replacing peripheral reference \(oldValue.identifier.uuidString) -> \(self.peripheral.identifier.uuidString)")
            oldValue.delegate = nil
            peripheral.delegate = self
            queue.sync { needsConfiguration = true }
        }
    }

    let queue = DispatchQueue(label: "com.kylebashour.Luka.PeripheralManager.queue", qos: .unspecified)

    private let commandLock = NSCondition()
    private var commandConditions = [CommandCondition]()
    private var commandError: Error?

    private(set) weak var central: CBCentralManager?
    let configuration: Configuration
    private var needsConfiguration = true

    weak var delegate: G7PeripheralManagerDelegate? {
        didSet {
            queue.sync { needsConfiguration = true }
        }
    }

    init(peripheral: CBPeripheral, configuration: Configuration, centralManager: CBCentralManager) {
        self.peripheral = peripheral
        self.central = centralManager
        self.configuration = configuration
        super.init()
        peripheral.delegate = self
        assertConfiguration()
    }

    // MARK: - Nested types

    struct Configuration {
        var serviceCharacteristics: [CBUUID: [CBUUID]] = [:]
        var notifyingCharacteristics: [CBUUID: [CBUUID]] = [:]
        var valueUpdateMacros: [CBUUID: (_ manager: G7PeripheralManager) -> Void] = [:]
    }

    enum CommandCondition {
        case notificationStateUpdate(characteristicUUID: CBUUID, enabled: Bool)
        case valueUpdate(characteristic: CBCharacteristic, matching: ((Data?) -> Bool)?)
        case write(characteristic: CBCharacteristic)
        case discoverServices
        case discoverCharacteristicsForService(serviceUUID: CBUUID)
    }
}

// MARK: - Configuration

extension G7PeripheralManager.Configuration {
    static var dexcomG7: G7PeripheralManager.Configuration {
        return G7PeripheralManager.Configuration(
            serviceCharacteristics: [
                SensorServiceUUID.cgmService.cbUUID: [
                    CGMServiceCharacteristicUUID.authentication.cbUUID,
                    CGMServiceCharacteristicUUID.control.cbUUID,
                    CGMServiceCharacteristicUUID.backfill.cbUUID,
                ]
            ],
            notifyingCharacteristics: [:],
            valueUpdateMacros: [:]
        )
    }
}

// MARK: - Operation sequence management

extension G7PeripheralManager {
    func configureAndRun(_ block: @escaping (_ manager: G7PeripheralManager) -> Void) -> (() -> Void) {
        return {
            if !self.needsConfiguration && self.peripheral.services == nil {
                self.log.error("Configured peripheral has no services. Reconfiguring…")
            }

            if self.needsConfiguration || self.peripheral.services == nil {
                do {
                    try self.applyConfiguration()
                    self.log.info("Peripheral configuration completed")
                    if let delegate = self.delegate {
                        try delegate.completeConfiguration(for: self)
                        self.log.info("Delegate configuration completed")
                        self.needsConfiguration = false
                    } else {
                        self.log.error("No delegate set configured")
                    }
                } catch {
                    self.log.error("Error applying peripheral configuration: \(error)")
                }
            }

            block(self)
        }
    }

    func perform(_ block: @escaping (_ manager: G7PeripheralManager) -> Void) {
        queue.async(execute: configureAndRun(block))
    }

    private func assertConfiguration() {
        log.debug("assertConfiguration")
        perform { _ in }
    }

    private func applyConfiguration(discoveryTimeout: TimeInterval = 2) throws {
        try discoverServices(configuration.serviceCharacteristics.keys.map { $0 }, timeout: discoveryTimeout)

        for service in peripheral.services ?? [] {
            guard let characteristics = configuration.serviceCharacteristics[service.uuid] else {
                continue
            }
            try discoverCharacteristics(characteristics, for: service, timeout: discoveryTimeout)
        }

        for (serviceUUID, characteristicUUIDs) in configuration.notifyingCharacteristics {
            guard let service = peripheral.services?.itemWithUUID(serviceUUID) else {
                throw PeripheralManagerError.unknownCharacteristic
            }

            for characteristicUUID in characteristicUUIDs {
                guard let characteristic = service.characteristics?.itemWithUUID(characteristicUUID) else {
                    throw PeripheralManagerError.unknownCharacteristic
                }
                guard !characteristic.isNotifying else { continue }
                try setNotifyValue(true, for: characteristic, timeout: discoveryTimeout)
            }
        }
    }
}

// MARK: - Synchronous Commands

extension G7PeripheralManager {
    func runCommand(timeout: TimeInterval, command: () -> Void) throws {
        dispatchPrecondition(condition: .onQueue(queue))
        guard central?.state == .poweredOn && peripheral.state == .connected else {
            throw PeripheralManagerError.notReady
        }

        commandLock.lock()
        defer { commandLock.unlock() }

        guard commandConditions.isEmpty else {
            throw PeripheralManagerError.invalidConfiguration
        }

        command()

        guard !commandConditions.isEmpty else { return }

        let signaled = commandLock.wait(until: Date(timeIntervalSinceNow: timeout))

        defer {
            commandError = nil
            commandConditions = []
        }

        guard signaled else {
            throw PeripheralManagerError.timeout
        }

        if let error = commandError {
            throw PeripheralManagerError.cbPeripheralError(error)
        }
    }

    func addCondition(_ condition: CommandCondition) {
        dispatchPrecondition(condition: .onQueue(queue))
        commandConditions.append(condition)
    }

    func discoverServices(_ serviceUUIDs: [CBUUID], timeout: TimeInterval) throws {
        let servicesToDiscover = peripheral.servicesToDiscover(from: serviceUUIDs)
        guard servicesToDiscover.count > 0 else { return }

        try runCommand(timeout: timeout) {
            addCondition(.discoverServices)
            peripheral.discoverServices(serviceUUIDs)
        }
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID], for service: CBService, timeout: TimeInterval) throws {
        let characteristicsToDiscover = peripheral.characteristicsToDiscover(from: characteristicUUIDs, for: service)
        guard characteristicsToDiscover.count > 0 else { return }

        try runCommand(timeout: timeout) {
            addCondition(.discoverCharacteristicsForService(serviceUUID: service.uuid))
            peripheral.discoverCharacteristics(characteristicsToDiscover, for: service)
        }
    }

    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic, timeout: TimeInterval) throws {
        try runCommand(timeout: timeout) {
            addCondition(.notificationStateUpdate(characteristicUUID: characteristic.uuid, enabled: enabled))
            peripheral.setNotifyValue(enabled, for: characteristic)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension G7PeripheralManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        commandLock.lock()
        if let index = commandConditions.firstIndex(where: { if case .discoverServices = $0 { return true } else { return false } }) {
            commandConditions.remove(at: index)
            commandError = error
            if commandConditions.isEmpty { commandLock.broadcast() }
        }
        commandLock.unlock()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        commandLock.lock()
        if let index = commandConditions.firstIndex(where: { if case .discoverCharacteristicsForService(serviceUUID: service.uuid) = $0 { return true } else { return false } }) {
            commandConditions.remove(at: index)
            commandError = error
            if commandConditions.isEmpty { commandLock.broadcast() }
        }
        commandLock.unlock()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        commandLock.lock()
        if let index = commandConditions.firstIndex(where: { if case .notificationStateUpdate(characteristicUUID: characteristic.uuid, enabled: characteristic.isNotifying) = $0 { return true } else { return false } }) {
            commandConditions.remove(at: index)
            commandError = error
            if commandConditions.isEmpty { commandLock.broadcast() }
        }
        commandLock.unlock()
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        commandLock.lock()
        if let index = commandConditions.firstIndex(where: { if case .write(characteristic: characteristic) = $0 { return true } else { return false } }) {
            commandConditions.remove(at: index)
            commandError = error
            if commandConditions.isEmpty { commandLock.broadcast() }
        }
        commandLock.unlock()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        commandLock.lock()
        var notifyDelegate = false

        if let index = commandConditions.firstIndex(where: {
            if case .valueUpdate(characteristic: characteristic, matching: let matching) = $0 {
                return matching?(characteristic.value) ?? true
            }
            return false
        }) {
            commandConditions.remove(at: index)
            commandError = error
            if commandConditions.isEmpty { commandLock.broadcast() }
        } else if let macro = configuration.valueUpdateMacros[characteristic.uuid] {
            macro(self)
        } else if commandConditions.isEmpty {
            notifyDelegate = true
        }

        commandLock.unlock()

        if notifyDelegate {
            delegate?.peripheralManager(self, didUpdateValueFor: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        delegate?.peripheralManager(self, didReadRSSI: RSSI, error: error)
    }

    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        delegate?.peripheralManagerDidUpdateName(self)
    }
}

// MARK: - CBCentralManagerDelegate

extension G7PeripheralManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            log.debug("centralManagerDidUpdateState to poweredOn")
            assertConfiguration()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log.debug("didConnect to \(peripheral.identifier.uuidString)")
        if peripheral.state == .connected {
            assertConfiguration()
        }
    }
}

// MARK: - Helpers

extension G7PeripheralManager {
    private func getCharacteristicWithUUID(_ uuid: CGMServiceCharacteristicUUID) -> CBCharacteristic? {
        guard let service = peripheral.services?.itemWithUUIDString(SensorServiceUUID.cgmService.rawValue) else {
            return nil
        }
        return service.characteristics?.itemWithUUIDString(uuid.rawValue)
    }

    func setNotifyValue(_ enabled: Bool, for characteristicUUID: CGMServiceCharacteristicUUID, timeout: TimeInterval = 2) throws {
        guard let characteristic = getCharacteristicWithUUID(characteristicUUID) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        try setNotifyValue(enabled, for: characteristic, timeout: timeout)
    }
}
