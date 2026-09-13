//
//  LiveActivityManager.swift
//  Luka
//
//  Created by Claude on 1/2/26.
//

import ActivityKit
import Defaults
import Dexcom
import Foundation
import KeychainAccess
import TelemetryDeck
import UIKit
import WidgetKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private let client = HTTPClient()
    private let reporter = ClientEventReporter()

    private var observationTasks: [String: Task<Void, Never>] = [:]
    private var activityTokens: [String: String] = [:]
    /// Whether each observed activity was started by a push-to-start push. Only knowable
    /// for activities first seen through `activityUpdates` (their seeded content carries
    /// the server's `ps` flag before any update push overwrites it); activities already
    /// running at launch are `nil` = unknown.
    private var launchedByPush: [String: Bool?] = [:]
    private var activityUpdatesTask: Task<Void, Never>?
    private var pushToStartTask: Task<Void, Never>?

    private init() {
        // First thing on any launch: did we come up at all, and in what state? For a
        // push-to-start restart the system is supposed to wake the app in the background;
        // an `app_launch` in the server's telemetry shortly after its `push_started` is
        // the proof, and its absence is the finding.
        let existing = Activity<ReadingAttributes>.activities
        reporter.record("app_launch", [
            "app_state": Self.describe(UIApplication.shared.applicationState),
            "activities": String(existing.count),
            "protected_data": String(UIApplication.shared.isProtectedDataAvailable),
            "restart_enabled": String(Defaults[.autoRestartLiveActivity]),
            "has_pts_token": String(Defaults[.pushToStartToken] != nil),
        ])

        // Observe existing activities
        for activity in existing {
            observeActivity(activity, source: "existing")
        }

        syncState()

        // Observe new activities as they're created
        activityUpdatesTask = Task {
            for await activity in Activity<ReadingAttributes>.activityUpdates {
                observeActivity(activity, source: "updates")
                syncState()
            }
        }

        // Observe the device's push-to-start token and persist it. Persisting (rather
        // than holding it only in memory) means a push-token rotation that
        // background-relaunches the app still carries the token on re-registration —
        // otherwise the fresh process sends nil before this stream re-yields, which
        // clears the token server-side and breaks the hour-7 auto-restart.
        //
        // The token arrives even when no activity is running. Only act on a real
        // change: the stream re-yields the same token on most cold launches, and
        // re-registering then is wasted work — routine rotations already carry the
        // persisted token. On a genuine change (or first acquisition while an activity
        // is already running) we re-register so the server learns the new token now
        // instead of waiting for the next rotation.
        pushToStartTask = Task {
            for await data in Activity<ReadingAttributes>.pushToStartTokenUpdates {
                await handlePushToStartToken(data, source: "stream")
            }
        }

        // The stream alone is not enough. It can stay silent for an entire process
        // lifetime after the system has rotated the token (seen on iOS 26.6: five launches,
        // zero yields), so this device sat on a token persisted weeks earlier while every
        // restart push went to a token iOS no longer had — APNs accepts a push to a stale
        // token without complaint. Read the property directly after a short delay (Apple's
        // own recommendation for the launch timing race) and again on every foreground.
        Task {
            try? await Task.sleep(for: .seconds(2))
            await refreshPushToStartToken(source: "launch")
        }
    }

    /// Reads the system's current push-to-start token and reconciles it with what we
    /// persisted, re-registering running activities if it changed.
    func refreshPushToStartToken(source: String) async {
        await handlePushToStartToken(Activity<ReadingAttributes>.pushToStartToken, source: source)
    }

    private func handlePushToStartToken(_ data: Data?, source: String) async {
        guard let data else {
            reporter.record("push_to_start_token", ["source": source, "available": "false"])
            return
        }
        let token = data.map { String(format: "%02x", $0) }.joined()
        let changed = token != Defaults[.pushToStartToken]
        // Every read is reported, changed or not: if the server keeps pushing to a token
        // this device no longer reports, the mismatch shows up here.
        reporter.record("push_to_start_token", [
            "source": source,
            "changed": String(changed),
            "had_token": String(Defaults[.pushToStartToken] != nil),
            "pts_prefix": String(token.prefix(8)),
        ])
        TelemetryDeck.signal(
            "LiveActivity.pushToStartTokenUpdated",
            parameters: [
                "source": source,
                "changed": String(changed),
                "hadToken": String(Defaults[.pushToStartToken] != nil),
                "runningActivities": String(Activity<ReadingAttributes>.activities.count),
            ]
        )
        guard changed else { return }
        Defaults[.pushToStartToken] = token
        await reregisterRunningActivities()
    }

    private static func describe(_ state: UIApplication.State) -> String {
        switch state {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }

    /// Ships any queued client events now — called on foreground so observations from a
    /// wake that was suspended before its upload finished don't wait for the next event.
    func flushClientEvents() async {
        await reporter.flushNow()
    }

    func syncState(excluding excludedID: String? = nil) {
        ReadingAttributes.syncIsRunningDefault(excluding: excludedID)
        ControlCenter.shared.reloadAllControls()
    }

    private func observeActivity(_ activity: Activity<ReadingAttributes>, source: String) {
        guard observationTasks[activity.id] == nil else { return }

        // A push-to-start-launched activity arrives through `activityUpdates` with the
        // server's seeded content, whose `ps` flag is set. That first observation is the
        // device-side proof that a 7-hour restart actually produced an activity; a
        // `push_started` on the server with no such observation means iOS didn't create
        // it. `ps` is also set on every later update push (it means "server holds a
        // push-to-start token"), so for activities already running at launch it says
        // nothing about how they started — those report unknown.
        let pushToStart: Bool? = source == "updates" ? (activity.content.state.ps == true) : nil
        launchedByPush[activity.id] = pushToStart
        let pushToStartLabel = pushToStart.map(String.init) ?? "unknown"
        TelemetryDeck.signal(
            "LiveActivity.activityObserved",
            parameters: [
                "source": source,
                "pushToStart": pushToStartLabel,
                "state": String(describing: activity.activityState),
            ]
        )
        reporter.record("activity_observed", activityID: activity.id, [
            "source": source,
            "push_to_start": pushToStartLabel,
            "state": String(describing: activity.activityState),
            "reason": activity.content.state.r ?? "",
        ])

        let stateTask = Task {
            for await state in activity.activityStateUpdates {
                switch state {
                case .dismissed, .ended:
                    let pushToStartLabel = (launchedByPush[activity.id] ?? nil).map(String.init) ?? "unknown"
                    TelemetryDeck.signal(
                        "LiveActivity.activityEnded",
                        parameters: [
                            "state": String(describing: state),
                            "pushToStart": pushToStartLabel,
                            "hadToken": String(activityTokens[activity.id] != nil),
                        ]
                    )
                    reporter.record("activity_ended", activityID: activity.id, [
                        "state": String(describing: state),
                        "push_to_start": pushToStartLabel,
                        "had_token": String(activityTokens[activity.id] != nil),
                    ])
                    observationTasks.removeValue(forKey: activity.id)
                    activityTokens.removeValue(forKey: activity.id)
                    launchedByPush.removeValue(forKey: activity.id)
                    // Dismissal happens while the app is backgrounded (you're on the Lock
                    // Screen), so the app is suspended moments later. Hold a background
                    // assertion across the *entire* teardown — not just the network call —
                    // so the shared-default write actually reaches the App Group store and
                    // the control reload isn't dropped before suspension. Otherwise the
                    // Control Center toggle's currentValue() keeps reading the stale
                    // "running" value even after Control Center is reopened.
                    //
                    // Exclude this activity from the running check: Activity.activities can
                    // still report it as running for a moment after this state update fires.
                    await client.withBackgroundTask(name: "LiveActivity.handleEnd") {
                        syncState(excluding: activity.id)
                        await sendEndLiveActivity(activityID: activity.id)
                    }
                    return
                case .active, .pending, .stale:
                    break
                @unknown default:
                    break
                }
            }
        }

        let tokenTask = Task {
            for await token in activity.pushTokenUpdates {
                let tokenString = token.map { String(format: "%02x", $0) }.joined()
                let kind: String = activityTokens[activity.id] == nil ? "initial" : "update"
                let pushToStart = launchedByPush[activity.id] ?? nil
                activityTokens[activity.id] = tokenString
                TelemetryDeck.signal(
                    "LiveActivity.receivedToken",
                    parameters: ["kind": kind, "pushToStart": pushToStart.map(String.init) ?? "unknown"]
                )
                reporter.record("token_received", activityID: activity.id, [
                    "kind": kind,
                    "push_to_start": pushToStart.map(String.init) ?? "unknown",
                    "token_prefix": String(tokenString.prefix(8)),
                ])
                // On a wake or launch the just-dismissed activity is still in
                // `Activity.activities` for a moment and its token stream can re-yield.
                // Registering it again used to race the new activity's registration on
                // the server and could delete the new activity's token. Never send for
                // an activity that is already over.
                switch activity.activityState {
                case .dismissed, .ended:
                    reporter.record("token_send_skipped", activityID: activity.id, [
                        "kind": kind, "reason": "activity_ended", "state": String(describing: activity.activityState),
                    ])
                    continue
                case .active, .pending, .stale:
                    break
                @unknown default:
                    break
                }
                await sendStartLiveActivity(
                    activityID: activity.id, token: tokenString, kind: kind, pushToStart: pushToStart
                )
            }
        }

        // Store a task that waits for state changes and cancels the token task when done
        observationTasks[activity.id] = Task {
            await stateTask.value
            tokenTask.cancel()
        }
    }

    private func sendStartLiveActivity(
        activityID: String, token: String, kind: String, pushToStart: Bool? = nil
    ) async {
        guard let username = Keychain.shared.username,
              let password = Keychain.shared.password,
              let accountLocation = Defaults[.accountLocation],
              username != DexcomHelper.mockEmail else {
            // A silent return here is exactly the kind of gap that hides a failed restart
            // registration; the queue is flushed once credentials are readable.
            reporter.record("token_send_skipped", activityID: activityID, [
                "kind": kind,
                "reason": "credentials",
                "push_to_start": pushToStart.map(String.init) ?? "unknown",
                "has_username": String(Keychain.shared.username != nil),
                "has_password": String(Keychain.shared.password != nil),
                "has_location": String(Defaults[.accountLocation] != nil),
            ])
            return
        }

        let range: GraphRange = .threeHours

        // Gate auto-restart behind the experimental toggle: only hand the server
        // a push-to-start token (and the attributes to replay) when enabled.
        let restartEnabled = Defaults[.autoRestartLiveActivity]
        // Reconcile with the system's current token right before we hand one over, so a
        // rotation the stream never reported can't be sent to the server.
        if restartEnabled {
            await refreshPushToStartToken(source: "register")
        }
        let payload = StartLiveActivityRequest(
            activityID: activityID,
            pushToken: token,
            environment: .current,
            username: username,
            password: password,
            accountLocation: accountLocation,
            duration: range.timeInterval + 60 * 15,
            preferences: LiveActivityPreferences(
                targetRange: Int(Defaults[.targetRangeLowerBound])...Int(Defaults[.targetRangeUpperBound]),
                unit: Defaults[.unit],
                alertsEnabled: Defaults[.liveActivityAlertsEnabled]
            ),
            pushToStartToken: restartEnabled ? Defaults[.pushToStartToken] : nil,
            attributesType: restartEnabled ? "ReadingAttributes" : nil,
            attributes: restartEnabled ? try? JSONValue(encoding: ReadingAttributes(range: range)) : nil,
            pushToStart: pushToStart
        )

        let pushToStartLabel = pushToStart.map(String.init) ?? "unknown"
        await client.withBackgroundTask(name: "LiveActivity.sendStartLiveActivity") {
            do {
                let request = try client.makePostRequest("start-live-activity", body: payload)
                let (_, response) = try await client.send(request)
                // 410: the server knows this activity already ended (it dismissed it, or a
                // newer one replaced it). Not a failure — stop tracking it.
                if response.statusCode == 410 {
                    TelemetryDeck.signal("LiveActivity.tokenRejected", parameters: ["kind": kind])
                    reporter.record("token_send_rejected", activityID: activityID, [
                        "kind": kind, "push_to_start": pushToStartLabel,
                    ])
                    return
                }
                // Any other 4xx/5xx is a failed registration: the server has no token and
                // will never push to this activity. Treat it as an error, not a success.
                guard (200..<300).contains(response.statusCode) else {
                    throw HTTPClient.StatusError(statusCode: response.statusCode)
                }
                TelemetryDeck.signal(
                    "LiveActivity.sentToken",
                    parameters: ["kind": kind, "pushToStart": pushToStartLabel, "restartEnabled": String(restartEnabled)]
                )
                reporter.record("token_sent", activityID: activityID, [
                    "kind": kind, "push_to_start": pushToStartLabel, "restart_enabled": String(restartEnabled),
                ])
            } catch {
                TelemetryDeck.signal(
                    "LiveActivity.failedToSendToken",
                    parameters: ["kind": kind, "pushToStart": pushToStartLabel, "error": String(describing: type(of: error))]
                )
                reporter.record("token_send_failed", activityID: activityID, [
                    "kind": kind, "push_to_start": pushToStartLabel, "error": String(describing: error).prefix(120).description,
                ])
            }
        }
    }

    /// Re-sends the start registration for every running activity using its
    /// most recent push token, so the server receives the latest push-to-start
    /// token. Called when the push-to-start token updates.
    private func reregisterRunningActivities() async {
        for activity in Activity<ReadingAttributes>.activities {
            switch activity.activityState {
            case .active, .pending, .stale:
                if let token = activityTokens[activity.id] {
                    await sendStartLiveActivity(activityID: activity.id, token: token, kind: "update")
                }
            case .dismissed, .ended:
                break
            @unknown default:
                break
            }
        }
    }

    /// Debug-only: asks the server to manually trigger a push-to-start restart for each
    /// running activity, for testing without waiting for the time limit. Requires the
    /// auto-restart experiment to have been enabled (so the server has a push-to-start token).
    func debugRestartLiveActivityOnServer() async {
        guard let username = Keychain.shared.username else { return }
        for activity in Activity<ReadingAttributes>.activities {
            let payload = DebugRestartLiveActivityRequest(
                username: username,
                activityID: activity.id
            )
            await client.withBackgroundTask(name: "LiveActivity.debugRestart") {
                do {
                    let request = try client.makePostRequest("restart-live-activity", body: payload)
                    try await client.send(request)
                    TelemetryDeck.signal("LiveActivity.sentDebugRestart")
                } catch {
                    TelemetryDeck.signal("LiveActivity.failedToSendDebugRestart")
                }
            }
        }
    }

    func endLiveActivityOnServer() async {
        for activity in Activity<ReadingAttributes>.activities {
            await sendEndLiveActivity(activityID: activity.id)
        }
    }

    func endAllLiveActivitiesOnServer() async {
        guard let username = Keychain.shared.username else { return }

        let payload = EndLiveActivitiesRequest(username: username)

        await client.withBackgroundTask(name: "LiveActivity.sendEndAllLiveActivities") {
            do {
                let request = try client.makePostRequest("end-live-activities", body: payload)
                try await client.send(request)
                TelemetryDeck.signal("LiveActivity.sentEndAll")
            } catch {
                TelemetryDeck.signal("LiveActivity.failedToSendEndAll")
            }
        }
    }

    private func sendEndLiveActivity(activityID: String) async {
        guard let username = Keychain.shared.username else { return }

        // Match is by activityID, so end regardless of whether a push token was captured
        // locally — the server no-ops if it has no entry for this activity.
        let payload = EndLiveActivityRequest(username: username, activityID: activityID)

        await client.withBackgroundTask(name: "LiveActivity.sendEndLiveActivity") {
            do {
                let request = try client.makePostRequest("end-live-activity", body: payload)
                let (_, response) = try await client.send(request)
                guard (200..<300).contains(response.statusCode) else {
                    throw HTTPClient.StatusError(statusCode: response.statusCode)
                }
                TelemetryDeck.signal("LiveActivity.sentEnd")
                reporter.record("end_sent", activityID: activityID)
            } catch {
                TelemetryDeck.signal("LiveActivity.failedToSendEnd")
                reporter.record("end_send_failed", activityID: activityID, [
                    "error": String(describing: error).prefix(120).description,
                ])
            }
        }
    }
}
