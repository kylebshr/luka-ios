//
//  PhoneWatchRelay.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Defaults
import Dexcom
import Foundation
import WatchConnectivity

/// Relays Direct to G7 readings from the iPhone to the watch, which can't
/// follow the sensor over Bluetooth itself.
///
/// Two transports:
/// - `updateApplicationContext` on every reading — cheap latest-state that's
///   also delivered when the watch app next launches or activates.
/// - `transferCurrentComplicationUserInfo` selectively — the budgeted
///   (~50/day) high-priority transfer that wakes the watch app in the
///   background so it can reload its WidgetKit timelines. Sent when the
///   range bucket changes, the trend is moving fast, or as a half-hourly
///   heartbeat, to stay inside the budget.
@MainActor
final class PhoneWatchRelay: NSObject {
    static let shared = PhoneWatchRelay()

    private override init() {
        super.init()
    }

    func activateIfNeeded() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        if session.delegate !== self {
            session.delegate = self
        }
        if session.activationState != .activated {
            session.activate()
        }
    }

    /// Relays the current mode and readings; called after each ingest.
    func relayLatest() {
        relay(includeComplicationTransfer: true)
    }

    /// Relays a mode change immediately so the watch flips its UI without
    /// waiting for the next reading.
    func relayModeChange() {
        activateIfNeeded()
        relay(includeComplicationTransfer: false)
    }

    private func relay(includeComplicationTransfer: Bool) {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else {
            return
        }

        let payload = makePayload()
        try? session.updateApplicationContext(payload)

        if includeComplicationTransfer {
            transferComplicationIfDue(session: session, payload: payload)
        }
    }

    private func makePayload() -> [String: Any] {
        var payload: [String: Any] = [
            "mode": Defaults[.appMode]?.rawValue ?? "",
            "sentAt": Date.now,
        ]

        if Defaults[.appMode] == .direct,
           let readings = Defaults[.cachedReadings]?.readings,
           let data = try? JSONEncoder().encode(readings) {
            payload["readings"] = data
        }

        return payload
    }

    /// Complication transfers wake the watch but are budgeted (~50/day, and
    /// only counted while a Luka widget is on the active watch face), so
    /// send one only when the watch face genuinely needs to change soon:
    /// the reading crossed a range boundary, glucose is moving fast (at
    /// most every 10 minutes), or a 30-minute heartbeat so timestamps and
    /// history don't drift too far.
    private func transferComplicationIfDue(session: WCSession, payload: [String: Any]) {
        guard let latest = Defaults[.cachedReadings]?.latestReading else { return }

        let bucket = rangeBucket(for: latest.value)
        let sinceLast = Defaults[.lastComplicationTransferDate]
            .map { Date.now.timeIntervalSince($0) } ?? .infinity
        let bucketChanged = bucket != Defaults[.lastComplicationTransferBucket]
        let fastTrend = latest.trend == .doubleUp || latest.trend == .doubleDown

        guard bucketChanged
                || sinceLast >= 30 * 60
                || (fastTrend && sinceLast >= 10 * 60) else {
            return
        }

        session.transferCurrentComplicationUserInfo(payload)
        Defaults[.lastComplicationTransferDate] = .now
        Defaults[.lastComplicationTransferBucket] = bucket
    }

    private func rangeBucket(for value: Int) -> String {
        // Integer-truncated bounds, consistent with GlucoseReading.color(target:).
        if value < Int(Defaults[.targetRangeLowerBound]) {
            "low"
        } else if value > Int(Defaults[.targetRangeUpperBound]) {
            "high"
        } else {
            "inRange"
        }
    }
}

extension PhoneWatchRelay: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        // Relay current state as soon as the session is up, so a
        // just-installed watch app doesn't wait for the next reading.
        Task { @MainActor in
            self.relay(includeComplicationTransfer: false)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate for a newly paired watch.
        session.activate()
    }
}
