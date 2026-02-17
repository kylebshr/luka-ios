//
//  G7PeripheralManager.swift
//  Luka
//
//  Vendored from G7SensorKit (LoopKit Authors). Modified for Luka.
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

class G7PeripheralManager: NSObject {

    private let log = OSLog(g7Category: "G7PeripheralManager")

    var peripheral: CBPeripheral {
        didSet {
            guard oldValue !== peripheral else {
                return
            }

            log.g7Error("Replacing peripheral reference %{public}@ -> %{public}@", oldValue, peripheral)

            oldValue.delegate = nil
            peripheral.delegate = self

            queue.sync {
                self.needsConfiguration = true
            }
        }
    }

    let queue = DispatchQueue(label: "com.kylebashour.Luka.PeripheralManager.queue", qos: .unspecified)

    private let commandLock = NSCondition()
    private var commandConditions = [CommandCondition]()
    private var commandError: Error?

    private(set) weak var central: CBCentralManager?

    let configuration: Configuration

    // Confined to `queue`
    private var needsConfiguration = true

    weak var delegate: G7PeripheralManagerDelegate? {
        didSet {
            queue.sync {
                needsConfiguration = true
            }
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

    func requestExtendedVersion() throws {
        self.log.g7Default("Requesting sensor extended version")
        guard let service = peripheral.services?.itemWithUUID(SensorServiceUUID.cgmService.cbUUID) else {
            self.log.g7Error("Peripheral missing cgm service. Services = %{public}@", String(describing: peripheral.services))
            throw PeripheralManagerError.invalidConfiguration
        }

        guard let characteristic = service.characteristics?.itemWithUUID(CGMServiceCharacteristicUUID.control.cbUUID) else {
            throw PeripheralManagerError.unknownCharacteristic
        }

        try writeValue(Data([G7Opcode.extendedVersionTx.rawValue]), for: characteristic, type: .withResponse, timeout: 1)
    }
}

// MARK: - Nested types
extension G7PeripheralManager {
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

protocol G7PeripheralManagerDelegate: AnyObject {
    func peripheralManager(_ manager: G7PeripheralManager, didUpdateValueFor characteristic: CBCharacteristic)
    func peripheralManager(_ manager: G7PeripheralManager, didReadRSSI RSSI: NSNumber, error: Error?)
    func peripheralManagerDidUpdateName(_ manager: G7PeripheralManager)
    func completeConfiguration(for manager: G7PeripheralManager) throws
}

// MARK: - Operation sequence management
extension G7PeripheralManager {
    func configureAndRun(_ block: @escaping (_ manager: G7PeripheralManager) -> Void) -> (() -> Void) {
        return {
            if !self.needsConfiguration && self.peripheral.services == nil {
                self.log.g7Error("Configured peripheral has no services. Reconfiguring…")
            }

            if self.needsConfiguration || self.peripheral.services == nil {
                do {
                    try self.applyConfiguration()
                    self.log.g7Default("Peripheral configuration completed")
                    if let delegate = self.delegate {
                        try delegate.completeConfiguration(for: self)
                        self.log.g7Default("Delegate configuration completed")
                        self.needsConfiguration = false
                    } else {
                        self.log.g7Error("No delegate set configured")
                    }
                } catch let error {
                    self.log.g7Error("Error applying peripheral configuration: %{public}@", String(describing: error))
                }
            }

            block(self)
        }
    }

    func perform(_ block: @escaping (_ manager: G7PeripheralManager) -> Void) {
        queue.async(execute: configureAndRun(block))
    }

    private func assertConfiguration() {
        log.g7Debug("assertConfiguration")
        perform { (_) in
            // Intentionally empty to trigger configuration if necessary
        }
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

                guard !characteristic.isNotifying else {
                    continue
                }

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

        defer {
            commandLock.unlock()
        }

        guard commandConditions.isEmpty else {
            throw PeripheralManagerError.invalidConfiguration
        }

        command()

        guard !commandConditions.isEmpty else {
            return
        }

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

        guard servicesToDiscover.count > 0 else {
            return
        }

        try runCommand(timeout: timeout) {
            addCondition(.discoverServices)
            peripheral.discoverServices(serviceUUIDs)
        }
    }

    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID], for service: CBService, timeout: TimeInterval) throws {
        let characteristicsToDiscover = peripheral.characteristicsToDiscover(from: characteristicUUIDs, for: service)

        guard characteristicsToDiscover.count > 0 else {
            return
        }

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

    func readValue(for characteristic: CBCharacteristic, timeout: TimeInterval) throws -> Data? {
        try runCommand(timeout: timeout) {
            addCondition(.valueUpdate(characteristic: characteristic, matching: nil))
            peripheral.readValue(for: characteristic)
        }
        return characteristic.value
    }

    func writeValue(_ value: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType, timeout: TimeInterval) throws {
        try runCommand(timeout: timeout) {
            if case .withResponse = type {
                addCondition(.write(characteristic: characteristic))
            }
            peripheral.writeValue(value, for: characteristic, type: type)
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

        if let index = commandConditions.firstIndex(where: { if case .valueUpdate(characteristic: characteristic, matching: let matching) = $0 { return matching?(characteristic.value) ?? true } else { return false } }) {
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
        switch central.state {
        case .poweredOn:
            assertConfiguration()
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        switch peripheral.state {
        case .connected:
            assertConfiguration()
        default:
            break
        }
    }
}

// MARK: - Characteristic helpers
extension G7PeripheralManager {
    private func getCharacteristicWithUUID(_ uuid: CGMServiceCharacteristicUUID) -> CBCharacteristic? {
        return peripheral.getCharacteristicWithUUID(uuid)
    }

    func setNotifyValue(_ enabled: Bool,
        for characteristicUUID: CGMServiceCharacteristicUUID,
        timeout: TimeInterval = 2) throws
    {
        guard let characteristic = getCharacteristicWithUUID(characteristicUUID) else {
            throw PeripheralManagerError.unknownCharacteristic
        }
        try setNotifyValue(enabled, for: characteristic, timeout: timeout)
    }
}

fileprivate extension CBPeripheral {
    func getServiceWithUUID(_ uuid: SensorServiceUUID) -> CBService? {
        return services?.itemWithUUIDString(uuid.rawValue)
    }

    func getCharacteristicForServiceUUID(_ serviceUUID: SensorServiceUUID, withUUIDString UUIDString: String) -> CBCharacteristic? {
        guard let characteristics = getServiceWithUUID(serviceUUID)?.characteristics else {
            return nil
        }
        return characteristics.itemWithUUIDString(UUIDString)
    }

    func getCharacteristicWithUUID(_ uuid: CGMServiceCharacteristicUUID) -> CBCharacteristic? {
        return getCharacteristicForServiceUUID(.cgmService, withUUIDString: uuid.rawValue)
    }
}
