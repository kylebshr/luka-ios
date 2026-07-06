//
//  WatchSessionListener.swift
//  Watch
//
//  Created by Claude on 7/6/26.
//

import Defaults
import Dexcom
import Foundation
import WatchConnectivity
import WidgetKit

/// Receives Direct to G7 readings relayed from the iPhone and lands them in
/// the watch's local store — the same `Defaults[.cachedReadings]` the watch
/// app and its widgets already read.
///
/// Application context covers latest-state (including cold starts, via
/// `receivedApplicationContext` on activation); `didReceiveUserInfo` handles
/// the budgeted complication transfers that wake the app in the background,
/// where reloading WidgetKit timelines actually matters.
final class WatchSessionListener: NSObject {
    static let shared = WatchSessionListener()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func apply(_ payload: [String: Any]) {
        guard !payload.isEmpty else { return }

        let mode = (payload["mode"] as? String).flatMap(AppMode.init(rawValue:))
        if Defaults[.appMode] != mode {
            Defaults[.appMode] = mode
            if mode != .direct {
                // The phone left direct mode; drop its relayed readings.
                DirectReadingStore.clear()
            }
            WidgetCenter.shared.reloadAllTimelines()
        }

        guard mode == .direct,
              let data = payload["readings"] as? Data,
              let readings = try? JSONDecoder().decode([GlucoseReading].self, from: data) else {
            return
        }

        if DirectReadingStore.ingest(readings) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

extension WatchSessionListener: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        // Cold start: apply whatever context was delivered while inactive.
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        apply(userInfo)
    }
}
