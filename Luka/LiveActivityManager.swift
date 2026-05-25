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

    private var observationTasks: [String: Task<Void, Never>] = [:]
    private var activityTokens: [String: String] = [:]
    private var activityUpdatesTask: Task<Void, Never>?

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
    }

    func syncState() {
        if ReadingAttributes.syncIsRunningDefault() {
            ControlCenter.shared.reloadAllControls()
        }
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
                await sendStartLiveActivity(token: tokenString, kind: kind)
            }
        }

        // Store a task that waits for state changes and cancels the token task when done
        observationTasks[activity.id] = Task {
            await stateTask.value
            tokenTask.cancel()
        }
    }

    private func sendStartLiveActivity(token: String, kind: String) async {
        guard let username = Keychain.shared.username,
              let password = Keychain.shared.password,
              let accountLocation = Defaults[.accountLocation],
              username != DexcomHelper.mockEmail else {
            return
        }

        let range: GraphRange = .threeHours
        let payload = StartLiveActivityRequest(
            pushToken: token,
            environment: .current,
            username: username,
            password: password,
            accountLocation: accountLocation,
            duration: range.timeInterval + 60 * 15,
            preferences: LiveActivityPreferences(
                targetRange: Int(Defaults[.targetRangeLowerBound])...Int(Defaults[.targetRangeUpperBound]),
                unit: Defaults[.unit]
            )
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        var request = URLRequest(url: Backend.current.url(for: "start-live-activity"))
        request.httpMethod = "POST"
        request.httpBody = try! encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await withBackgroundTask(name: "LiveActivity.sendStartLiveActivity") {
            do {
                _ = try await URLSession.shared.data(for: request)
                TelemetryDeck.signal("LiveActivity.sentToken", parameters: ["kind": kind])
            } catch {
                TelemetryDeck.signal("LiveActivity.failedToSendToken", parameters: ["kind": kind])
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

        var request = URLRequest(url: Backend.current.url(for: "end-live-activities"))
        request.httpMethod = "POST"
        request.httpBody = try! JSONEncoder().encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await withBackgroundTask(name: "LiveActivity.sendEndAllLiveActivities") {
            do {
                _ = try await URLSession.shared.data(for: request)
                TelemetryDeck.signal("LiveActivity.sentEndAll")
            } catch {
                TelemetryDeck.signal("LiveActivity.failedToSendEndAll")
            }
        }
    }

    private func sendEndLiveActivity(activityID: String) async {
        guard let username = Keychain.shared.username,
              let pushToken = activityTokens[activityID] else { return }

        let payload = EndLiveActivityRequest(pushToken: pushToken, username: username)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        var request = URLRequest(url: Backend.current.url(for: "end-live-activity"))
        request.httpMethod = "POST"
        request.httpBody = try! encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        await withBackgroundTask(name: "LiveActivity.sendEndLiveActivity") {
            do {
                _ = try await URLSession.shared.data(for: request)
                TelemetryDeck.signal("LiveActivity.sentEnd")
            } catch {
                TelemetryDeck.signal("LiveActivity.failedToSendEnd")
            }
        }
    }

    private func withBackgroundTask(name: String, _ work: () async -> Void) async {
        let taskID = UIApplication.shared.beginBackgroundTask(withName: name)
        await work()
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }
}
