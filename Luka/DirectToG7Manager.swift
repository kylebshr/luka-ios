//
//  DirectToG7Manager.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Defaults
import DexcomKit
import Foundation
import TelemetryDeck

/// Prototype: follows a Dexcom G7 sensor directly over Bluetooth via
/// DexcomKit, riding alongside the official Dexcom app's session.
@MainActor @Observable final class DirectToG7Manager {
    static let shared = DirectToG7Manager()

    /// The active monitor; non-nil while Direct to G7 is enabled.
    private(set) var monitor: G7SensorMonitor?

    /// Mirrors `Defaults[.directToG7Enabled]`; setting it starts or stops
    /// following the sensor.
    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            Defaults[.directToG7Enabled] = isEnabled
            TelemetryDeck.signal(isEnabled ? "DirectToG7.enabled" : "DirectToG7.disabled")

            if isEnabled {
                start()
            } else {
                stop()
            }
        }
    }

    private init() {
        isEnabled = Defaults[.directToG7Enabled]
    }

    /// Resumes following at launch — including background relaunches for
    /// Bluetooth state restoration — when the setting is on.
    func syncState() {
        if isEnabled {
            start()
        }
    }

    /// Forgets the followed sensor so the next scan adopts fresh.
    func forgetSensor() {
        monitor?.forgetSensor()
    }

    private func start() {
        guard monitor == nil else { return }

        let monitor = G7SensorMonitor(
            configuration: G7Configuration(
                store: UserDefaultsStore(suiteName: "group.com.kylebashour.Glimpse"),
                restoreIdentifier: "com.kylebashour.Glimpse.dexcomkit"
            )
        )

        // With the default `.automatic` selection, `start()` has no failure
        // cases; if that ever changes, fail quietly rather than crash.
        try? monitor.start()
        self.monitor = monitor
    }

    private func stop() {
        monitor?.stop()
        monitor = nil
    }
}
