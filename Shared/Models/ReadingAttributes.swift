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

    // Both optional: activities started by older builds, and server push-to-start
    // restarts replaying their registered attributes, have neither.

    /// The `DexcomAccount` this activity follows; nil means the primary account.
    var accountID: UUID?
    /// Shown on the activity to tell several apart. Only set when more than one
    /// account was signed in at start.
    var accountName: String?

    init(range: GraphRange, accountID: UUID? = nil, accountName: String? = nil) {
        self.range = range
        self.accountID = accountID
        self.accountName = accountName
    }
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
            return activity.activityState.isRunning
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

extension ActivityState {
    var isRunning: Bool {
        switch self {
        case .active, .pending, .stale:
            true
        case .dismissed, .ended:
            false
        @unknown default:
            false
        }
    }
}
