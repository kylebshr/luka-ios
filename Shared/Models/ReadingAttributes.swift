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
        Activity<ReadingAttributes>.activities.contains { activity in
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

    /// Updates `Defaults[.isLiveActivityRunning]` to reflect the current Live Activity state.
    /// Returns true if the stored value changed.
    @discardableResult
    static func syncIsRunningDefault() -> Bool {
        let isRunning = hasRunningActivity
        guard Defaults[.isLiveActivityRunning] != isRunning else { return false }
        Defaults[.isLiveActivityRunning] = isRunning
        return true
    }
}
