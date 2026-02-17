//
//  G7Sensor.swift
//  Luka
//
//  Vendored from G7SensorKit (LoopKit Authors). Modified for Luka.
//

import Foundation
import CoreBluetooth
import os.log

public protocol G7SensorDelegate: AnyObject {
    func sensorDidConnect(_ sensor: G7Sensor, name: String)
    func sensorDisconnected(_ sensor: G7Sensor, suspectedEndOfSession: Bool)
    func sensor(_ sensor: G7Sensor, didError error: Error)
    func sensor(_ sensor: G7Sensor, didRead glucose: G7GlucoseMessage)
    func sensor(_ sensor: G7Sensor, didReadBackfill backfill: [G7BackfillMessage])
    func sensor(_ sensor: G7Sensor, didDiscoverNewSensor name: String, activatedAt: Date) -> Bool
    func sensor(_ sensor: G7Sensor, didReceive extendedVersion: ExtendedVersionMessage)
    func sensorConnectionStatusDidUpdate(_ sensor: G7Sensor)
}

public enum G7SensorError: Error {
    case authenticationError(String)
    case controlError(String)
    case observationError(String)
}

extension G7SensorError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .authenticationError(let description):
            return description
        case .controlError(let description):
            return description
        case .observationError(let description):
            return description
        }
    }
}

public enum G7SensorLifecycleState {
    case searching
    case warmup
    case ok
    case failed
    case gracePeriod
    case expired
}

public final class G7Sensor: G7BluetoothManagerDelegate {
    public static let defaultLifetime = TimeInterval(10 * 24 * 60 * 60) // 10 days
    public static let defaultWarmupDuration = TimeInterval(27 * 60) // 27 min
    public static let gracePeriod = TimeInterval(12 * 60 * 60) // 12 hours

    public weak var delegate: G7SensorDelegate?

    // MARK: - State confined to bluetoothManager.managerQueue
    var activationDate: Date?
    var needsVersionInfo: Bool = false
    private var lastConnection: Date?
    private var pendingAuth: Bool = false
    private var backfillBuffer: [G7BackfillMessage] = []

    private let log = OSLog(g7Category: "G7Sensor")
    private let bluetoothManager = G7BluetoothManager()
    private let delegateQueue = DispatchQueue(label: "com.kylebashour.Luka.G7Sensor.delegateQueue", qos: .unspecified)
    private var sensorID: String?

    public init(sensorID: String?) {
        self.sensorID = sensorID
        bluetoothManager.delegate = self
    }

    public func scanForNewSensor() {
        self.sensorID = nil
        bluetoothManager.disconnect()
        bluetoothManager.forgetPeripheral()
        bluetoothManager.scanForPeripheral()
    }

    public func resumeScanning() {
        bluetoothManager.scanForPeripheral()
    }

    public func stopScanning() {
        bluetoothManager.disconnect()
    }

    public var isScanning: Bool {
        return bluetoothManager.isScanning
    }

    public var isConnected: Bool {
        return bluetoothManager.isConnected
    }

    private func handleGlucoseMessage(message: G7GlucoseMessage, peripheralManager: G7PeripheralManager) {
        activationDate = Date().addingTimeInterval(-TimeInterval(message.messageTimestamp))
        peripheralManager.perform { (peripheral) in
            self.log.g7Debug("Listening for backfill responses")
            do {
                try peripheral.listenToCharacteristic(.backfill)
            } catch let error {
                self.log.g7Error("Error trying to enable notifications on backfill characteristic: %{public}@", String(describing: error))
                self.delegateQueue.async {
                    self.delegate?.sensor(self, didError: error)
                }
            }
        }

        if needsVersionInfo, let name = peripheralManager.peripheral.name, name == sensorID {
            peripheralManager.perform { (peripheral) in
                do {
                    try peripheral.requestExtendedVersion()
                } catch let error {
                    self.log.g7Error("Error trying to request extended version: %{public}@", String(describing: error))
                }
            }
        }

        if sensorID == nil, let name = peripheralManager.peripheral.name, let activationDate = activationDate {
            delegateQueue.async {
                guard let delegate = self.delegate else { return }

                if delegate.sensor(self, didDiscoverNewSensor: name, activatedAt: activationDate) {
                    self.sensorID = name
                    self.activationDate = activationDate
                    self.needsVersionInfo = true
                    self.delegate?.sensor(self, didRead: message)
                    self.bluetoothManager.stopScanning()
                    if self.needsVersionInfo, let name = peripheralManager.peripheral.name, name == self.sensorID {
                        peripheralManager.perform { (peripheral) in
                            do {
                                try peripheral.requestExtendedVersion()
                            } catch let error {
                                self.log.g7Error("Error trying to request extended version on initial detection: %{public}@", String(describing: error))
                            }
                        }
                    }
                }
            }
        } else if sensorID != nil {
            delegateQueue.async {
                self.delegate?.sensor(self, didRead: message)
            }
        } else {
            self.log.g7Error("Dropping unhandled glucose message: %{public}@", String(describing: message))
        }
    }

    // MARK: - G7BluetoothManagerDelegate

    func bluetoothManager(_ manager: G7BluetoothManager, readied peripheralManager: G7PeripheralManager) -> Bool {
        var shouldStopScanning = false

        if let sensorID = sensorID, sensorID == peripheralManager.peripheral.name {
            shouldStopScanning = true
            delegateQueue.async {
                self.delegate?.sensorDidConnect(self, name: sensorID)
            }
        }

        peripheralManager.perform { (peripheral) in
            self.log.g7Info("Listening for authentication responses for %{public}@", String(describing: peripheralManager.peripheral.name))
            do {
                try peripheral.listenToCharacteristic(.authentication)
                self.pendingAuth = true
            } catch let error {
                self.delegateQueue.async {
                    self.delegate?.sensor(self, didError: error)
                }
            }
        }
        return shouldStopScanning
    }

    func bluetoothManager(_ manager: G7BluetoothManager, readyingFailed peripheralManager: G7PeripheralManager, with error: Error) {
        delegateQueue.async {
            self.delegate?.sensor(self, didError: error)
        }
    }

    func peripheralDidDisconnect(_ manager: G7BluetoothManager, peripheralManager: G7PeripheralManager, wasRemoteDisconnect: Bool) {
        if let sensorID = sensorID, sensorID == peripheralManager.peripheral.name {
            flushBackfillBuffer()

            let suspectedEndOfSession: Bool
            self.log.g7Info("Sensor disconnected: wasRemoteDisconnect:%{public}@", String(describing: wasRemoteDisconnect))
            if pendingAuth, wasRemoteDisconnect {
                suspectedEndOfSession = true
            } else {
                suspectedEndOfSession = false
            }
            pendingAuth = false

            delegateQueue.async {
                self.delegate?.sensorDisconnected(self, suspectedEndOfSession: suspectedEndOfSession)
            }
        }
    }

    func bluetoothManager(_ manager: G7BluetoothManager, shouldConnectPeripheral peripheral: CBPeripheral) -> PeripheralConnectionCommand {
        guard let name = peripheral.name else {
            log.g7Debug("Not connecting to unnamed peripheral: %{public}@", String(describing: peripheral))
            return .ignore
        }

        // Dexcom G7: "DXCMxx", Dexcom One+: "DX02xx"
        if name.hasPrefix("DXCM") || name.hasPrefix("DX02") {
            if let sensorName = sensorID, name.suffix(2) == sensorName.suffix(2) {
                return .makeActive
            } else if sensorID == nil {
                return .connect
            }
        }

        log.g7Info("Not connecting to peripheral: %{public}@", name)
        return .ignore
    }

    func bluetoothManager(_ manager: G7BluetoothManager, peripheralManager: G7PeripheralManager, didReceiveControlResponse response: Data) {
        guard response.count > 0 else { return }

        log.g7Default("Received control response: %{public}@", response.hexadecimalString)

        switch G7Opcode(rawValue: response[0]) {
        case .glucoseTx?:
            if let glucoseMessage = G7GlucoseMessage(data: response) {
                handleGlucoseMessage(message: glucoseMessage, peripheralManager: peripheralManager)
            } else {
                delegateQueue.async {
                    self.delegate?.sensor(self, didError: G7SensorError.observationError("Unable to handle glucose control response"))
                }
            }
        case .extendedVersionTx:
            if let extendedVersionMessage = ExtendedVersionMessage(data: response) {
                log.g7Default("Received %{public}@", String(describing: extendedVersionMessage))
                delegateQueue.async {
                    self.delegate?.sensor(self, didReceive: extendedVersionMessage)
                    self.needsVersionInfo = false
                }
            }
        case .backfillFinished:
            flushBackfillBuffer()
        default:
            break
        }
    }

    func flushBackfillBuffer() {
        if backfillBuffer.count > 0 {
            let backfill = backfillBuffer
            self.backfillBuffer = []
            delegateQueue.async {
                self.delegate?.sensor(self, didReadBackfill: backfill)
            }
        }
    }

    func bluetoothManager(_ manager: G7BluetoothManager, didReceiveBackfillResponse response: Data) {
        log.g7Debug("Received backfill response: %{public}@", response.hexadecimalString)

        guard response.count == 9 else { return }

        if let msg = G7BackfillMessage(data: response) {
            backfillBuffer.append(msg)
        }
    }

    func bluetoothManager(_ manager: G7BluetoothManager, peripheralManager: G7PeripheralManager, didReceiveAuthenticationResponse response: Data) {
        if let message = AuthChallengeRxMessage(data: response), message.isBonded, message.isAuthenticated {
            log.g7Debug("Observed authenticated session. enabling notifications for control characteristic.")
            pendingAuth = false
            peripheralManager.perform { (peripheral) in
                do {
                    try peripheral.listenToCharacteristic(.control)
                } catch let error {
                    self.log.g7Error("Error trying to enable notifications on control characteristic: %{public}@", String(describing: error))
                    self.delegateQueue.async {
                        self.delegate?.sensor(self, didError: error)
                    }
                }
            }
        } else {
            log.g7Debug("Ignoring authentication response: %{public}@", response.hexadecimalString)
        }
    }

    func bluetoothManagerScanningStatusDidChange(_ manager: G7BluetoothManager) {
        self.delegateQueue.async {
            self.delegate?.sensorConnectionStatusDidUpdate(self)
        }
    }
}

// MARK: - Helpers
fileprivate extension G7PeripheralManager {
    func listenToCharacteristic(_ characteristic: CGMServiceCharacteristicUUID) throws {
        do {
            try setNotifyValue(true, for: characteristic)
        } catch let error {
            throw G7SensorError.controlError("Error enabling notification for \(characteristic): \(error)")
        }
    }
}
