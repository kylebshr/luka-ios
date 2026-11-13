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
        !runningActivities(excluding: []).isEmpty
    }

    /// The Live Activities that haven't ended or been dismissed, ignoring those in `excludedIDs`.
    /// Exclude activities you've just seen end: `Activity.activities` can still report them as
    /// running for a moment after their state update fires, which would otherwise leave the
    /// stored state stuck "on".
    static func runningActivities(excluding excludedIDs: Set<String>) -> [Activity<ReadingAttributes>] {
        Activity<ReadingAttributes>.activities.filter { activity in
            !excludedIDs.contains(activity.id) && activity.activityState.isRunning
        }
    }

    /// Updates `Defaults[.isLiveActivityRunning]` and `Defaults[.liveActivityAccountIDs]` to
    /// reflect the current Live Activities, ignoring those in `excludedIDs` (see
    /// `runningActivities(excluding:)`). Returns true if either stored value changed.
    @discardableResult
    static func syncIsRunningDefault(excluding excludedIDs: Set<String> = []) -> Bool {
        let running = runningActivities(excluding: excludedIDs)
        var changed = false

        let isRunning = !running.isEmpty
        if Defaults[.isLiveActivityRunning] != isRunning {
            Defaults[.isLiveActivityRunning] = isRunning
            changed = true
        }

        if let accountIDs = AccountResolution.liveActivityAccountIDs(
            owningActivitiesWith: running.map(\.attributes.accountID),
            in: AccountStore.shared.accounts
        ), Defaults[.liveActivityAccountIDs] != accountIDs {
            Defaults[.liveActivityAccountIDs] = accountIDs
            changed = true
        }

        return changed
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
