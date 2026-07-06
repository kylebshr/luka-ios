//
//  DirectLiveActivityUpdater.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import ActivityKit
import Defaults
import Dexcom
import Foundation

/// Updates running Live Activities locally from the reading store in Direct
/// to G7 mode — no server, no push. Called on each new reading; the
/// `bluetooth-central` background wake provides the runtime to update.
///
/// Staleness is handled by `staleDate` alone: if Bluetooth stops delivering,
/// the app has no runtime to run timers anyway, and the Live Activity UI
/// already renders `context.isStale` as offline.
@MainActor
final class DirectLiveActivityUpdater {
    static let shared = DirectLiveActivityUpdater()

    private init() {}

    func updateActivities(sessionEnded: Bool = false) async {
        let readings = Defaults[.cachedReadings]?.readings ?? []

        for activity in Activity<ReadingAttributes>.activities {
            switch activity.activityState {
            case .active, .pending, .stale:
                // The state initializer filters history to the activity's range.
                var state = LiveActivityState(readings: readings, range: activity.attributes.range)
                if sessionEnded {
                    state.se = true
                    state.r = "Sensor session ended"
                }

                await activity.update(
                    ActivityContent(
                        state: state,
                        staleDate: .now.addingTimeInterval(15 * 60)
                    )
                )
            case .dismissed, .ended:
                break
            @unknown default:
                break
            }
        }
    }
}
