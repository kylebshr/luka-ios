//
//  BackendMigrator.swift
//  Luka
//
//  Created by Claude on 11/12/26.
//

import Foundation

@MainActor
protocol BackendMigratorHost: AnyObject {
    var isInForeground: Bool { get }
    var wantedBackend: Backend { get }
    var activeBackend: Backend { get set }
    /// Ends every running Live Activity on the device, returning their IDs.
    func endRunningActivitiesLocally() async -> [String]
    /// Tells `backend` an activity ended, returning whether it acknowledged.
    func endLiveActivity(_ activityID: String, on backend: Backend) async -> Bool
    func startLiveActivity() async throws
    func record(_ name: String, _ attributes: [String: String])
}

/// Moves this install from its active backend to the wanted one.
///
/// A backend only polls and pushes the activities registered with it, so a running Live
/// Activity can't change servers. Instead it's ended and a fresh one is started on the new
/// backend. That needs the app in the foreground (ActivityKit only starts activities
/// there), so background work keeps using the active backend until the next foreground.
@MainActor
final class BackendMigrator {
    private unowned let host: BackendMigratorHost
    private var inFlight: Task<Void, Never>?

    init(host: BackendMigratorHost) {
        self.host = host
    }

    func migrateIfNeeded() async {
        // Serialized: a trigger that arrives mid-migration waits, then re-checks.
        while let inFlight {
            await inFlight.value
        }
        guard host.isInForeground, host.wantedBackend != host.activeBackend else { return }

        let task = Task {
            await migrate(from: host.activeBackend, to: host.wantedBackend)
            // Cleared by the task itself, so a waiter never sees a finished migration
            // still in flight.
            inFlight = nil
        }
        inFlight = task
        await task.value
    }

    private func migrate(from old: Backend, to new: Backend) async {
        let endedIDs = await host.endRunningActivitiesLocally()

        // Only this device's activities: `end-live-activities` would also dismiss those of
        // other devices signed in to the same account. Best effort; if this fails, the old
        // server drops the token once APNs rejects a push to the ended activity.
        var endsAcknowledged = 0
        for activityID in endedIDs {
            if await host.endLiveActivity(activityID, on: old) {
                endsAcknowledged += 1
            }
        }

        host.activeBackend = new

        var attributes = [
            "from": old.rawValue,
            "to": new.rawValue,
            "ended_activities": String(endedIDs.count),
            "ends_acknowledged": String(endsAcknowledged),
            "restarted": "false",
        ]
        if !endedIDs.isEmpty {
            do {
                try await host.startLiveActivity()
                attributes["restarted"] = "true"
            } catch {
                attributes["restart_error"] = String(describing: error).prefix(120).description
            }
        }
        host.record("backend_migrated", attributes)
    }
}
