//
//  G7GlucoseService.swift
//  Luka
//
//  Created by Kyle Bashour on 2/16/26.
//

import Defaults
import Dexcom
import Foundation

/// Bridges G7 BLE sensor data to the GlucoseSource protocol used by the app.
/// Receives glucose messages from G7Sensor via delegate, converts to GlucoseReading,
/// caches readings, and provides them via the async GlucoseSource interface.
@MainActor
final class G7GlucoseService: GlucoseSource, @unchecked Sendable {

    enum ConnectionStatus: Equatable {
        case disconnected
        case scanning
        case connected(sensorName: String)
        case warmup
    }

    static let shared = G7GlucoseService()

    private(set) var connectionStatus: ConnectionStatus = .disconnected
    private(set) var sensorName: String?
    private(set) var activationDate: Date?
    private(set) var extendedVersion: ExtendedVersionMessage?

    private var sensor: G7Sensor?
    private var readings: [GlucoseReading] = []
    private let delegateAdapter = G7SensorDelegateAdapter()

    // Callback for UI to observe status changes
    var onStatusChange: (() -> Void)?
    var onNewReading: (() -> Void)?

    private init() {
        delegateAdapter.service = self
        restoreFromCache()
    }

    // MARK: - Sensor lifecycle

    func startWithExistingSensor() {
        let sensorID = Defaults[.g7SensorID]
        activationDate = Defaults[.g7ActivationDate]
        sensor = G7Sensor(sensorID: sensorID)
        sensor?.delegate = delegateAdapter
        sensor?.resumeScanning()
        connectionStatus = .scanning
        onStatusChange?()
    }

    func scanForNewSensor() {
        sensor?.stopScanning()
        sensor = G7Sensor(sensorID: nil)
        sensor?.delegate = delegateAdapter
        sensor?.scanForNewSensor()
        connectionStatus = .scanning
        onStatusChange?()
    }

    func stop() {
        sensor?.stopScanning()
        sensor = nil
        connectionStatus = .disconnected
        onStatusChange?()
    }

    var lifecycleState: G7SensorLifecycleState {
        guard let activationDate else { return .searching }

        let elapsed = Date.now.timeIntervalSince(activationDate)
        let lifetime = extendedVersion.map { $0.sessionLength } ?? G7Sensor.defaultLifetime
        let warmup = extendedVersion.map { $0.warmupDuration } ?? G7Sensor.defaultWarmupDuration

        if elapsed < warmup {
            return .warmup
        } else if elapsed < lifetime {
            return .ok
        } else if elapsed < lifetime + G7Sensor.gracePeriod {
            return .gracePeriod
        } else {
            return .expired
        }
    }

    var sensorExpirationDate: Date? {
        guard let activationDate else { return nil }
        let lifetime = extendedVersion.map { $0.sessionLength } ?? G7Sensor.defaultLifetime
        return activationDate.addingTimeInterval(lifetime)
    }

    // MARK: - GlucoseSource

    nonisolated func getGlucoseReadings() async throws -> [GlucoseReading] {
        await MainActor.run { readings }
    }

    nonisolated func getLatestGlucoseReading() async throws -> GlucoseReading? {
        await MainActor.run { readings.last }
    }

    // MARK: - Internal: called by delegate adapter

    func handleGlucoseMessage(_ message: G7GlucoseMessage) {
        guard let glucose = message.glucose, message.hasReliableGlucose else { return }

        let timestamp: Date
        if let activationDate {
            timestamp = activationDate.addingTimeInterval(TimeInterval(message.glucoseTimestamp))
        } else {
            timestamp = Date.now.addingTimeInterval(-TimeInterval(message.age))
        }

        let trend = trendDirection(from: message.trend)
        let reading = GlucoseReading(value: Int(glucose), trend: trend, date: timestamp)

        appendReading(reading)
        updateCache()
        onNewReading?()
    }

    func handleBackfill(_ backfillMessages: [G7BackfillMessage]) {
        guard let activationDate else { return }

        for message in backfillMessages {
            guard let glucose = message.glucose, message.hasReliableGlucose else { continue }

            let timestamp = activationDate.addingTimeInterval(TimeInterval(message.timestamp))
            let trend = trendDirection(from: message.trend)
            let reading = GlucoseReading(value: Int(glucose), trend: trend, date: timestamp)

            appendReading(reading)
        }

        updateCache()
        onNewReading?()
    }

    func handleSensorConnected(name: String) {
        sensorName = name
        connectionStatus = .connected(sensorName: name)
        onStatusChange?()
    }

    func handleSensorDisconnected(suspectedEndOfSession: Bool) {
        if suspectedEndOfSession {
            // Sensor session ended — clear sensor ID so we can pair a new one
            Defaults[.g7SensorID] = nil
            Defaults[.g7ActivationDate] = nil
            sensorName = nil
            activationDate = nil
        }
        connectionStatus = .scanning
        onStatusChange?()
    }

    func handleNewSensorDiscovered(name: String, activatedAt: Date) -> Bool {
        sensorName = name
        activationDate = activatedAt
        Defaults[.g7SensorID] = name
        Defaults[.g7ActivationDate] = activatedAt
        connectionStatus = .connected(sensorName: name)
        onStatusChange?()
        return true
    }

    func handleExtendedVersion(_ version: ExtendedVersionMessage) {
        extendedVersion = version
    }

    func handleConnectionStatusUpdate() {
        if let sensor, sensor.isScanning, connectionStatus != .scanning {
            connectionStatus = .scanning
            onStatusChange?()
        }
    }

    // MARK: - Private

    private func appendReading(_ reading: GlucoseReading) {
        // Avoid duplicates by timestamp
        if !readings.contains(where: { abs($0.date.timeIntervalSince(reading.date)) < 30 }) {
            readings.append(reading)
            readings.sort { $0.date < $1.date }

            // Keep last 24h of readings (288 readings at 5-min intervals)
            let cutoff = Date.now.addingTimeInterval(-24 * 60 * 60)
            readings.removeAll { $0.date < cutoff }
        }
    }

    private func updateCache() {
        let cache = GlucoseReadingsCache(
            readings: readings,
            duration: 24 * 60 * 60
        )
        Defaults[.cachedReadings] = cache
    }

    private func restoreFromCache() {
        if let cache = Defaults[.cachedReadings] {
            readings = cache.readings
        }
    }

    private func trendDirection(from rate: Double?) -> TrendDirection {
        guard let rate else { return .none }

        switch rate {
        case let x where x > 3.0:
            return .doubleUp
        case let x where x > 2.0:
            return .singleUp
        case let x where x > 1.0:
            return .fortyFiveUp
        case let x where x > -1.0:
            return .flat
        case let x where x > -2.0:
            return .fortyFiveDown
        case let x where x > -3.0:
            return .singleDown
        default:
            return .doubleDown
        }
    }
}

// MARK: - G7SensorDelegate adapter

/// Non-isolated adapter that forwards G7Sensor delegate calls to the MainActor-isolated service.
private final class G7SensorDelegateAdapter: G7SensorDelegate, @unchecked Sendable {
    weak var service: G7GlucoseService?

    func sensorDidConnect(_ sensor: G7Sensor, name: String) {
        let service = service
        Task { @MainActor in service?.handleSensorConnected(name: name) }
    }

    func sensorDisconnected(_ sensor: G7Sensor, suspectedEndOfSession: Bool) {
        let service = service
        Task { @MainActor in service?.handleSensorDisconnected(suspectedEndOfSession: suspectedEndOfSession) }
    }

    func sensor(_ sensor: G7Sensor, didError error: Error) {
        print("G7 Sensor error: \(error)")
    }

    func sensor(_ sensor: G7Sensor, didRead glucose: G7GlucoseMessage) {
        let service = service
        let glucose = glucose
        Task { @MainActor in service?.handleGlucoseMessage(glucose) }
    }

    func sensor(_ sensor: G7Sensor, didReadBackfill backfill: [G7BackfillMessage]) {
        let service = service
        let backfill = backfill
        Task { @MainActor in service?.handleBackfill(backfill) }
    }

    func sensor(_ sensor: G7Sensor, didDiscoverNewSensor name: String, activatedAt: Date) -> Bool {
        let service = service
        Task { @MainActor in
            _ = service?.handleNewSensorDiscovered(name: name, activatedAt: activatedAt)
        }
        return true
    }

    func sensor(_ sensor: G7Sensor, didReceive extendedVersion: ExtendedVersionMessage) {
        let service = service
        let extendedVersion = extendedVersion
        Task { @MainActor in service?.handleExtendedVersion(extendedVersion) }
    }

    func sensorConnectionStatusDidUpdate(_ sensor: G7Sensor) {
        let service = service
        Task { @MainActor in service?.handleConnectionStatusUpdate() }
    }
}
