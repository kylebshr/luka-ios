//
//  LiveActivityBackends.swift
//  Luka
//
//  Created by Claude on 11/12/26.
//

import Defaults
import Foundation

extension Defaults.Keys {
    // Device-local: activity IDs belong to this install. `nil` until the first launch of a
    // build that routes per activity (see `LiveActivityManager.init`).
    static let liveActivityBackends = Key<LiveActivityBackends?>("liveActivityBackends", default: nil, suite: .shared)
}

/// Which backend each Live Activity was registered with.
///
/// A backend polls and pushes only the activities registered with it, so every call about
/// an activity (token rotations, end, debug restart) must go to the backend that first
/// registered it. Only a new activity follows `Backend.current`; a change of setting or
/// rollout therefore takes effect at the next start or 7-hour restart, without moving a
/// running activity.
struct LiveActivityBackends: Codable, Equatable, Defaults.Serializable {
    private(set) var byActivityID: [String: Backend] = [:]

    init(byActivityID: [String: Backend] = [:]) {
        self.byActivityID = byActivityID
    }

    /// The backend `activityID` is registered with, or `current` if it was never registered.
    func backend(for activityID: String, current: Backend) -> Backend {
        byActivityID[activityID] ?? current
    }

    /// The backend to register `activityID` with: the one it already has, or `current` for
    /// a new activity, which is remembered from then on.
    mutating func register(_ activityID: String, current: Backend) -> Backend {
        if let backend = byActivityID[activityID] {
            return backend
        }
        byActivityID[activityID] = current
        return current
    }

    mutating func forget(_ activityID: String) {
        byActivityID.removeValue(forKey: activityID)
    }

    /// Forgets activities that are no longer running, returning what was forgotten.
    mutating func prune(keeping runningIDs: Set<String>) -> [String: Backend] {
        let gone = byActivityID.filter { !runningIDs.contains($0.key) }
        for id in gone.keys {
            byActivityID.removeValue(forKey: id)
        }
        return gone
    }

    /// Every backend that may hold a session for this install. A backend without one
    /// treats an end-all as a no-op.
    func allBackends(current: Backend) -> [Backend] {
        let backends = Set(Backend.deployed + [current] + byActivityID.values)
        return Backend.allCases.filter(backends.contains)
    }
}
