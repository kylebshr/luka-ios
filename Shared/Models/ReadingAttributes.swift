//
//  ReadingAttributes.swift
//  LukaWidget
//
//  Created by Kyle Bashour on 10/16/25.
//

import ActivityKit
import Defaults
import Foundation
import Dexcom

struct ReadingAttributes: ActivityAttributes {
    typealias ContentState = LiveActivityState

    var range: GraphRange
}

extension ReadingAttributes {
    /// Returns true if there is at least one Live Activity that has not yet ended or been dismissed.
    static var hasRunningActivity: Bool {
        hasRunningActivity(excluding: nil)
    }

    /// Returns true if there is at least one running Live Activity, ignoring the activity with
    /// `excludedID`. Use this when reacting to a specific activity's end/dismissal: `Activity.activities`
    /// can still include that activity (reporting a running state) for a moment after the state update
    /// fires, which would otherwise leave the flag stuck "on".
    static func hasRunningActivity(excluding excludedID: String?) -> Bool {
        Activity<ReadingAttributes>.activities.contains { activity in
            guard activity.id != excludedID else { return false }
            switch activity.activityState {
            case .active, .pending, .stale:
                return true
            case .dismissed, .ended:
                return false
            @unknown default:
                return false
            }
        }
    }

    /// Updates `Defaults[.isLiveActivityRunning]` to reflect the current Live Activity state,
    /// optionally ignoring the activity with `excludedID` (see `hasRunningActivity(excluding:)`).
    /// Returns true if the stored value changed.
    @discardableResult
    static func syncIsRunningDefault(excluding excludedID: String? = nil) -> Bool {
        let isRunning = hasRunningActivity(excluding: excludedID)
        guard Defaults[.isLiveActivityRunning] != isRunning else { return false }
        Defaults[.isLiveActivityRunning] = isRunning
        return true
    }
}
