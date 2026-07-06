//
//  DirectToG7Manager.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Defaults
import Dexcom
import DexcomKit
import Foundation
import TelemetryDeck
import WidgetKit

/// The hub of Direct to G7 mode: follows the sensor over Bluetooth via
/// DexcomKit (riding alongside the official Dexcom app's session) and fans
/// each reading out to the local store, widgets, Live Activities, and the
/// watch relay.
@MainActor @Observable final class DirectToG7Manager {
    static let shared = DirectToG7Manager()

    /// The active monitor; non-nil while following in Direct to G7 mode.
    private(set) var monitor: G7SensorMonitor?

    /// The most recent non-fatal error the monitor reported, for the
    /// adoption UI — notably `authenticationRejected`, which means the
    /// Dexcom app hasn't established a session with the sensor. Cleared
    /// when a reading arrives.
    private(set) var lastError: DexcomKit.DexcomError?

    private var eventsTask: Task<Void, Never>?

    private init() {}

    /// Resumes following at launch — including background relaunches for
    /// Bluetooth state restoration — when the app is in Direct to G7 mode.
    func syncState() {
        if Defaults[.appMode] == .direct {
            startFollowing()
        }
    }

    /// Enters Direct to G7 mode: clears any cloud-cached readings so the
    /// store only ever holds one source, then starts following.
    func switchToDirectMode() {
        Defaults[.appMode] = .direct
        DirectReadingStore.clear()
        TelemetryDeck.signal("Mode.selected", parameters: ["mode": "direct"])
        startFollowing()
        PhoneWatchRelay.shared.relayModeChange()
    }

    /// Leaves Direct to G7 mode entirely: stops following, forgets the
    /// sensor, and clears everything the mode persisted. The app routes
    /// back to the mode chooser.
    func leaveDirectMode() {
        monitor?.forgetSensor()
        stopFollowing()
        DirectReadingStore.clear()
        Defaults[.directSensorAdopted] = false
        Defaults[.directSensorNameSuffix] = nil
        Defaults[.appMode] = nil
        TelemetryDeck.signal("DirectToG7.left")
        PhoneWatchRelay.shared.relayModeChange()
    }

    func startFollowing() {
        guard monitor == nil else { return }

        let selection: SensorSelection = if let suffix = Defaults[.directSensorNameSuffix],
                                            !suffix.trimmingCharacters(in: .whitespaces).isEmpty {
            .nameSuffix(suffix)
        } else {
            .automatic
        }

        let monitor = G7SensorMonitor(
            configuration: G7Configuration(
                selection: selection,
                store: UserDefaultsStore(suiteName: "group.com.kylebashour.Glimpse"),
                restoreIdentifier: "com.kylebashour.Glimpse.dexcomkit"
            )
        )

        // The only failure case is an empty name suffix, which the selection
        // above can't produce; if that ever changes, fail quietly rather
        // than crash.
        try? monitor.start()
        self.monitor = monitor
        observeEvents(from: monitor)

        PhoneWatchRelay.shared.activateIfNeeded()
    }

    func stopFollowing() {
        eventsTask?.cancel()
        eventsTask = nil
        monitor?.stop()
        monitor = nil
    }

    /// Forgets the followed sensor so the next scan adopts fresh — for
    /// replacing a sensor — and routes back to the adoption flow. Readings
    /// already in the store stay; they're valid history that ages out.
    func forgetSensor() {
        monitor?.forgetSensor()
        Defaults[.directSensorAdopted] = false
        TelemetryDeck.signal("DirectToG7.sensorForgotten")
    }

    /// Applies a new sensor-targeting suffix (nil or empty means automatic)
    /// and restarts the monitor so the next scan uses it.
    func applySensorSelection(suffix: String?) {
        let trimmed = suffix?.trimmingCharacters(in: .whitespaces) ?? ""
        Defaults[.directSensorNameSuffix] = trimmed.isEmpty ? nil : trimmed

        if monitor != nil {
            stopFollowing()
            startFollowing()
        }
    }

    private func observeEvents(from monitor: G7SensorMonitor) {
        eventsTask = Task { [weak self] in
            for await event in monitor.events() {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }

    private func handle(_ event: G7Event) async {
        switch event {
        case .connectionStateChanged:
            break

        case .reading(let reading):
            await ingest([reading])

        case .backfill(let readings):
            await ingest(readings)

        case .sessionEstablished:
            if !Defaults[.directSensorAdopted] {
                Defaults[.directSensorAdopted] = true
                TelemetryDeck.signal("DirectToG7.adoption.completed")
            }

        case .sessionEnded(let reason):
            TelemetryDeck.signal("DirectToG7.sessionEnded", parameters: ["reason": "\(reason)"])
            await DirectLiveActivityUpdater.shared.updateActivities(sessionEnded: true)

        case .error(let error):
            lastError = error
            if error == .authenticationRejected && !Defaults[.directSensorAdopted] {
                TelemetryDeck.signal("DirectToG7.adoption.failed", parameters: ["error": "\(error)"])
            }
        }
    }

    private func ingest(_ readings: [DexcomKit.GlucoseReading]) async {
        lastError = nil
        await fanOut(readings.bridged())
    }

    /// Persists bridged readings and, when the latest changed, fans out to
    /// widgets, the Live Activity, and the watch. Backfill and re-delivered
    /// readings that just fill history don't wake anything.
    private func fanOut(_ readings: [Dexcom.GlucoseReading]) async {
        guard DirectReadingStore.ingest(readings) else { return }

        WidgetCenter.shared.reloadAllTimelines()
        await DirectLiveActivityUpdater.shared.updateActivities()
        PhoneWatchRelay.shared.relayLatest()
    }

    #if DEBUG
    /// Pushes synthetic readings through the same fan-out as real Bluetooth
    /// readings, for end-to-end testing in the simulator.
    func simulateReadings(_ readings: [Dexcom.GlucoseReading]) async {
        await fanOut(readings)
    }
    #endif
}
