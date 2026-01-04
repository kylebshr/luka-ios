//
//  G7Sensor.swift
//  Luka
//
//  Adapted from G7SensorKit - Coordinates G7 BLE communication
//

import Foundation
import CoreBluetooth
import os.log
import Dexcom

public protocol G7SensorDelegate: AnyObject {
    func sensorDidConnect(_ sensor: G7Sensor, name: String)
    func sensorDisconnected(_ sensor: G7Sensor, suspectedEndOfSession: Bool)
    func sensor(_ sensor: G7Sensor, didError error: Error)
    func sensor(_ sensor: G7Sensor, didRead reading: GlucoseReading)
    func sensor(_ sensor: G7Sensor, didReadBackfill readings: [GlucoseReading])
    func sensor(_ sensor: G7Sensor, didDiscoverNewSensor name: String, activatedAt: Date) -> Bool
    func sensorConnectionStatusDidUpdate(_ sensor: G7Sensor)
}

public enum G7SensorError: Error, CustomStringConvertible {
    case authenticationError(String)
    case controlError(String)
    case observationError(String)

    public var description: String {
        switch self {
        case .authenticationError(let desc): return desc
        case .controlError(let desc): return desc
        case .observationError(let desc): return desc
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
    public static let lifetime = TimeInterval(10 * 24 * 60 * 60) // 10 days
    public static let warmupDuration = TimeInterval(25 * 60) // 25 minutes
    public static let gracePeriod = TimeInterval(12 * 60 * 60) // 12 hours

    public weak var delegate: G7SensorDelegate?

    var activationDate: Date?
    private var lastConnection: Date?
    private var pendingAuth: Bool = false
    private var backfillBuffer: [G7BackfillMessage] = []
    private var latestMessage: G7GlucoseMessage?

    private let log = Logger(subsystem: "com.kylebashour.Luka", category: "G7Sensor")
    private let bluetoothManager = G7BluetoothManager()
    private let delegateQueue = DispatchQueue(label: "com.kylebashour.Luka.G7Sensor.delegateQueue", qos: .unspecified)

    private var sensorID: String?

    public init(sensorID: String? = nil) {
        self.sensorID = sensorID
        bluetoothManager.delegate = self
    }

    public func scanForNewSensor() {
        sensorID = nil
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

        peripheralManager.perform { peripheral in
            self.log.debug("Listening for backfill responses")
            do {
                try peripheral.setNotifyValue(true, for: .backfill)
            } catch {
                self.log.error("Error enabling backfill notifications: \(error)")
                self.delegateQueue.async {
                    self.delegate?.sensor(self, didError: error)
                }
            }
        }

        if sensorID == nil, let name = peripheralManager.peripheral.name, let activationDate {
            delegateQueue.async {
                guard let delegate = self.delegate else { return }

                if delegate.sensor(self, didDiscoverNewSensor: name, activatedAt: activationDate) {
                    self.sensorID = name
                    self.activationDate = activationDate
                    if let reading = message.toGlucoseReading(activationDate: activationDate) {
                        self.delegate?.sensor(self, didRead: reading)
                    }
                    self.bluetoothManager.stopScanning()
                }
            }
        } else if sensorID != nil, let activationDate {
            latestMessage = message
            delegateQueue.async {
                if let reading = message.toGlucoseReading(activationDate: activationDate) {
                    self.delegate?.sensor(self, didRead: reading)
                }
            }
        } else {
            log.error("Dropping unhandled glucose message: \(message.debugDescription)")
        }
    }

    // MARK: - G7BluetoothManagerDelegate

    func bluetoothManager(_ manager: G7BluetoothManager, readied peripheralManager: G7PeripheralManager) -> Bool {
        var shouldStopScanning = false

        if let sensorID, sensorID == peripheralManager.peripheral.name {
            shouldStopScanning = true
            delegateQueue.async {
                self.delegate?.sensorDidConnect(self, name: sensorID)
            }
        }

        peripheralManager.perform { peripheral in
            self.log.info("Listening for authentication responses for \(peripheralManager.peripheral.name ?? "unknown")")
            do {
                try peripheral.setNotifyValue(true, for: .authentication)
                self.pendingAuth = true
            } catch {
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
        if let sensorID, sensorID == peripheralManager.peripheral.name {
            let suspectedEndOfSession = pendingAuth && wasRemoteDisconnect
            pendingAuth = false

            delegateQueue.async {
                self.delegate?.sensorDisconnected(self, suspectedEndOfSession: suspectedEndOfSession)
            }
        }
    }

    func bluetoothManager(_ manager: G7BluetoothManager, shouldConnectPeripheral peripheral: CBPeripheral) -> PeripheralConnectionCommand {
        guard let name = peripheral.name else {
            log.debug("Not connecting to unnamed peripheral")
            return .ignore
        }

        // G7 advertises as "DXCMxx", later reports full name "Dexcomxx"
        if name.hasPrefix("DXCM") {
            if let sensorName = sensorID, name.suffix(2) == sensorName.suffix(2) {
                return .makeActive
            } else if sensorID == nil {
                return .connect
            }
        }

        log.info("Not connecting to peripheral: \(name)")
        return .ignore
    }

    func bluetoothManager(_ manager: G7BluetoothManager, peripheralManager: G7PeripheralManager, didReceiveControlResponse response: Data) {
        guard response.count > 0 else { return }

        log.debug("Received control response: \(response.hexadecimalString)")

        switch G7Opcode(rawValue: response[0]) {
        case .glucoseTx?:
            if let glucoseMessage = G7GlucoseMessage(data: response) {
                handleGlucoseMessage(message: glucoseMessage, peripheralManager: peripheralManager)
            } else {
                delegateQueue.async {
                    self.delegate?.sensor(self, didError: G7SensorError.observationError("Unable to parse glucose message"))
                }
            }

        case .backfillFinished:
            if backfillBuffer.count > 0, let activationDate {
                let readings = backfillBuffer.compactMap { $0.toGlucoseReading(activationDate: activationDate) }
                delegateQueue.async {
                    self.delegate?.sensor(self, didReadBackfill: readings)
                    self.backfillBuffer = []
                }
            }

        default:
            break
        }
    }

    func bluetoothManager(_ manager: G7BluetoothManager, didReceiveBackfillResponse response: Data) {
        log.debug("Received backfill response: \(response.hexadecimalString)")

        guard response.count == 9 else { return }

        if let msg = G7BackfillMessage(data: response) {
            backfillBuffer.append(msg)
        }
    }

    func bluetoothManager(_ manager: G7BluetoothManager, peripheralManager: G7PeripheralManager, didReceiveAuthenticationResponse response: Data) {
        if let message = AuthChallengeRxMessage(data: response), message.isBonded, message.isAuthenticated {
            log.debug("Observed authenticated session. Enabling control characteristic notifications.")
            pendingAuth = false

            peripheralManager.perform { peripheral in
                do {
                    try peripheral.setNotifyValue(true, for: .control)
                } catch {
                    self.log.error("Error enabling control notifications: \(error)")
                    self.delegateQueue.async {
                        self.delegate?.sensor(self, didError: error)
                    }
                }
            }
        } else {
            log.debug("Ignoring authentication response: \(response.hexadecimalString)")
        }
    }

    func bluetoothManagerScanningStatusDidChange(_ manager: G7BluetoothManager) {
        delegateQueue.async {
            self.delegate?.sensorConnectionStatusDidUpdate(self)
        }
    }
}
