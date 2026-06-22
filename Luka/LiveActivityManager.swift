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

    /// Latest push-to-start token for this device. Sent to the server (when the
    /// auto-restart experiment is enabled) so it can restart the Live Activity
    /// after the time limit is reached.
    private var pushToStartToken: String?

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

        // Observe the device's push-to-start token. This arrives even when no
        // activity is running; re-register any running activity so the server
        // picks up the token (covers the first-launch race where the update
        // token is sent before the push-to-start token exists).
        pushToStartTask = Task {
            for await data in Activity<ReadingAttributes>.pushToStartTokenUpdates {
                pushToStartToken = data.map { String(format: "%02x", $0) }.joined()
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
            pushToStartToken: restartEnabled ? pushToStartToken : nil,
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
        guard let username = Keychain.shared.username,
              let pushToken = activityTokens[activityID] else { return }

        let payload = EndLiveActivityRequest(pushToken: pushToken, username: username, activityID: activityID)

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
