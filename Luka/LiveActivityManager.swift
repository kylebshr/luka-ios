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

    private var observationTasks: [String: Task<Void, Never>] = [:]
    private var activityTokens: [String: String] = [:]
    private var activityUpdatesTask: Task<Void, Never>?
    private var pushToStartTask: Task<Void, Never>?

    private init() {
        // Observe existing activities
        for activity in Activity<ReadingAttributes>.activities {
            observeActivity(activity)
        }

        syncState()

        // Observe new activities as they're created
        activityUpdatesTask = Task {
            for await activity in Activity<ReadingAttributes>.activityUpdates {
                observeActivity(activity)
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
                let token = data.map { String(format: "%02x", $0) }.joined()
                guard token != Defaults[.pushToStartToken] else { continue }
                Defaults[.pushToStartToken] = token
                await reregisterRunningActivities()
            }
        }
    }

    func syncState() {
        ReadingAttributes.syncIsRunningDefault()
        ControlCenter.shared.reloadAllControls()
    }

    private func observeActivity(_ activity: Activity<ReadingAttributes>) {
        guard observationTasks[activity.id] == nil else { return }

        let stateTask = Task {
            for await state in activity.activityStateUpdates {
                switch state {
                case .dismissed, .ended:
                    await sendEndLiveActivity(activityID: activity.id)
                    observationTasks.removeValue(forKey: activity.id)
                    activityTokens.removeValue(forKey: activity.id)
                    syncState()
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
                activityTokens[activity.id] = tokenString
                TelemetryDeck.signal("LiveActivity.receivedToken", parameters: ["kind": kind])
                await sendStartLiveActivity(activityID: activity.id, token: tokenString, kind: kind)
            }
        }

        // Store a task that waits for state changes and cancels the token task when done
        observationTasks[activity.id] = Task {
            await stateTask.value
            tokenTask.cancel()
        }
    }

    private func sendStartLiveActivity(activityID: String, token: String, kind: String) async {
        guard let username = Keychain.shared.username,
              let password = Keychain.shared.password,
              let accountLocation = Defaults[.accountLocation],
              username != DexcomHelper.mockEmail else {
            return
        }

        let range: GraphRange = .threeHours

        // Gate auto-restart behind the experimental toggle: only hand the server
        // a push-to-start token (and the attributes to replay) when enabled.
        let restartEnabled = Defaults[.autoRestartLiveActivity]
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
            attributes: restartEnabled ? try? JSONValue(encoding: ReadingAttributes(range: range)) : nil
        )

        await client.withBackgroundTask(name: "LiveActivity.sendStartLiveActivity") {
            do {
                let request = try client.makePostRequest("start-live-activity", body: payload)
                try await client.send(request)
                TelemetryDeck.signal("LiveActivity.sentToken", parameters: ["kind": kind])
            } catch {
                TelemetryDeck.signal("LiveActivity.failedToSendToken", parameters: ["kind": kind])
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
                try await client.send(request)
                TelemetryDeck.signal("LiveActivity.sentEnd")
            } catch {
                TelemetryDeck.signal("LiveActivity.failedToSendEnd")
            }
        }
    }
}
