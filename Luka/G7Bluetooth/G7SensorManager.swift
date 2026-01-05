//
//  G7SensorManager.swift
//  Luka
//
//  Integration layer connecting G7 BLE sensor to Luka's Live Activity
//

#if canImport(ActivityKit)
import ActivityKit
#endif
import Defaults
import Dexcom
import Foundation
import os.log

@MainActor
@Observable
public final class G7SensorManager {
    public static let shared = G7SensorManager()

    public enum ConnectionState: Equatable {
        case disconnected
        case scanning
        case connected(sensorName: String)
    }

    private static let maxReadingAge: TimeInterval = 24 * 60 * 60 // 24 hours

    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var latestReading: GlucoseReading?
    private(set) var isEnabled: Bool = false

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
        log.info("Starting G7 BLE sensor")
        sensor.resumeScanning()
        updateConnectionState()
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
        } else if sensor.isScanning {
            connectionState = .scanning
        } else {
            connectionState = .disconnected
        }
    }

    /// Stores a new reading, discarding readings older than 24 hours
    private func storeReading(_ reading: GlucoseReading) {
        var readings = Defaults[.g7Readings] ?? []

        // Remove readings older than 24 hours
        let cutoff = Date.now.addingTimeInterval(-Self.maxReadingAge)
        readings = readings.filter { $0.date >= cutoff }

        // Add new reading if not already present
        if !readings.contains(where: { $0.date == reading.date }) {
            readings.append(reading)
            readings.sort { $0.date < $1.date }
        }

        Defaults[.g7Readings] = readings
        log.info("Stored reading, total count: \(readings.count)")
    }

    /// Stores multiple readings, discarding readings older than 24 hours
    private func storeReadings(_ newReadings: [GlucoseReading]) {
        var readings = Defaults[.g7Readings] ?? []

        // Remove readings older than 24 hours
        let cutoff = Date.now.addingTimeInterval(-Self.maxReadingAge)
        readings = readings.filter { $0.date >= cutoff }

        // Add new readings that aren't already present
        for reading in newReadings where reading.date >= cutoff {
            if !readings.contains(where: { $0.date == reading.date }) {
                readings.append(reading)
            }
        }

        readings.sort { $0.date < $1.date }
        Defaults[.g7Readings] = readings
        log.info("Stored \(newReadings.count) backfill readings, total count: \(readings.count)")
    }

    #if canImport(ActivityKit)
    private func updateLiveActivity() {
        guard let activity = Activity<ReadingAttributes>.activities.first else { return }

        let range = activity.attributes.range
        let readings = Defaults[.g7Readings] ?? []
        let cutoff = Date.now.addingTimeInterval(-range.timeInterval)
        let filteredReadings = readings.filter { $0.date >= cutoff }

        let newState = LiveActivityState(readings: filteredReadings, range: range)

        let content = ActivityContent(
            state: newState,
            staleDate: newState.c?.date.addingTimeInterval(10 * 60)
        )

        Task {
            await activity.update(content)
            log.info("Updated Live Activity with \(filteredReadings.count) readings")
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
            storeReading(reading)

            #if canImport(ActivityKit)
            updateLiveActivity()
            #endif
        }
    }

    nonisolated public func sensor(_ sensor: G7Sensor, didReadBackfill readings: [GlucoseReading]) {
        Task { @MainActor in
            log.info("Received \(readings.count) backfill readings")
            storeReadings(readings)

            #if canImport(ActivityKit)
            updateLiveActivity()
            #endif
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
