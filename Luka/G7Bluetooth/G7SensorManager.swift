//
//  G7SensorManager.swift
//  Luka
//
//  Integration layer connecting G7 BLE sensor to Luka's Live Activity
//

#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation
import Dexcom
import os.log

@MainActor
public final class G7SensorManager: ObservableObject {
    public static let shared = G7SensorManager()

    public enum ConnectionState: Equatable {
        case disconnected
        case scanning
        case connected(sensorName: String)
    }

    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var latestReading: GlucoseReading?
    @Published public private(set) var isEnabled: Bool = false

    private let sensor: G7Sensor
    private let log = Logger(subsystem: "com.kylebashour.Luka", category: "G7SensorManager")
    private var sensorID: String?

    private init() {
        sensor = G7Sensor()
        sensor.delegate = self
    }

    /// Start BLE scanning for G7 sensor
    public func start() {
        guard !isEnabled else { return }
        isEnabled = true
        connectionState = .scanning  // Set immediately, don't wait for CBCentralManager
        log.info("Starting G7 BLE sensor")
        sensor.resumeScanning()
    }

    /// Stop BLE scanning and disconnect
    public func stop() {
        guard isEnabled else { return }
        isEnabled = false
        log.info("Stopping G7 BLE sensor")
        sensor.stopScanning()
        connectionState = .disconnected
    }

    /// Scan for a new sensor (forgets current sensor)
    public func scanForNewSensor() {
        sensorID = nil
        sensor.scanForNewSensor()
        updateConnectionState()
    }

    private func updateConnectionState() {
        if sensor.isConnected, let sensorID {
            connectionState = .connected(sensorName: sensorID)
        } else if isEnabled {
            // If enabled, assume scanning even if CBCentralManager isn't ready yet
            connectionState = .scanning
        } else {
            connectionState = .disconnected
        }
    }

    #if canImport(ActivityKit)
    private func updateLiveActivity(with reading: GlucoseReading) {
        guard let activity = Activity<ReadingAttributes>.activities.first else { return }

        // For BLE mode, we only have the current reading (no history for graph)
        let newState = LiveActivityState(
            c: reading,
            h: [], // No history in BLE-only mode
            se: nil
        )

        let content = ActivityContent(
            state: newState,
            staleDate: reading.date.addingTimeInterval(10 * 60)
        )

        Task {
            await activity.update(content)
            log.info("Updated Live Activity with BLE reading: \(reading.value)")
        }
    }
    #endif
}

// MARK: - G7SensorDelegate

extension G7SensorManager: G7SensorDelegate {
    nonisolated public func sensorDidConnect(_ sensor: G7Sensor, name: String) {
        Task { @MainActor in
            log.info("Sensor connected: \(name)")
            sensorID = name
            connectionState = .connected(sensorName: name)
        }
    }

    nonisolated public func sensorDisconnected(_ sensor: G7Sensor, suspectedEndOfSession: Bool) {
        Task { @MainActor in
            log.info("Sensor disconnected, endOfSession: \(suspectedEndOfSession)")
            if suspectedEndOfSession {
                sensorID = nil
            }
            updateConnectionState()
        }
    }

    nonisolated public func sensor(_ sensor: G7Sensor, didError error: Error) {
        Task { @MainActor in
            log.error("Sensor error: \(error)")
        }
    }

    nonisolated public func sensor(_ sensor: G7Sensor, didRead reading: GlucoseReading) {
        Task { @MainActor in
            log.info("Received glucose reading: \(reading.value) mg/dL")
            latestReading = reading

            #if canImport(ActivityKit)
            updateLiveActivity(with: reading)
            #endif
        }
    }

    nonisolated public func sensor(_ sensor: G7Sensor, didReadBackfill readings: [GlucoseReading]) {
        Task { @MainActor in
            log.info("Received \(readings.count) backfill readings")
            // Could store these for graph display if needed
        }
    }

    nonisolated public func sensor(_ sensor: G7Sensor, didDiscoverNewSensor name: String, activatedAt: Date) -> Bool {
        log.info("Discovered new sensor: \(name), activated at: \(activatedAt)")
        // Always accept new sensors for now
        return true
    }

    nonisolated public func sensorConnectionStatusDidUpdate(_ sensor: G7Sensor) {
        Task { @MainActor in
            updateConnectionState()
        }
    }
}
