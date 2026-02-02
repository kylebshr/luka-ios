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
import WidgetKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var observationTasks: [String: Task<Void, Never>] = [:]
    private var activityUpdatesTask: Task<Void, Never>?

    private init() {
        // Observe existing activities
        for activity in Activity<ReadingAttributes>.activities {
            observeActivity(activity, isExisting: true)
        }

        syncState()

        // Observe new activities as they're created
        activityUpdatesTask = Task {
            for await activity in Activity<ReadingAttributes>.activityUpdates {
                observeActivity(activity, isExisting: false)
                syncState()
            }
        }
    }

    func syncState() {
        let hasActivities = !Activity<ReadingAttributes>.activities.isEmpty
        if Defaults[.isLiveActivityRunning] != hasActivities {
            Defaults[.isLiveActivityRunning] = hasActivities
            ControlCenter.shared.reloadAllControls()
        }
    }

    private func observeActivity(_ activity: Activity<ReadingAttributes>, isExisting: Bool) {
        guard observationTasks[activity.id] == nil else { return }

        let activityIdPrefix = String(activity.id.prefix(8))
        let totalActivities = Activity<ReadingAttributes>.activities.count

        TelemetryDeck.signal(
            "LiveActivity.observing",
            parameters: [
                "activityIdPrefix": activityIdPrefix,
                "activityState": activity.activityState.telemetryName,
                "isExisting": isExisting ? "true" : "false",
                "totalActivities": "\(totalActivities)"
            ]
        )

        let stateTask = Task {
            for await state in activity.activityStateUpdates {
                TelemetryDeck.signal(
                    "LiveActivity.stateChanged",
                    parameters: [
                        "activityIdPrefix": activityIdPrefix,
                        "newState": state.telemetryName,
                        "totalActivities": "\(Activity<ReadingAttributes>.activities.count)"
                    ]
                )

                switch state {
                case .dismissed, .ended:
                    await sendEndLiveActivity()
                    observationTasks.removeValue(forKey: activity.id)
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
                let currentState = activity.activityState

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                dateFormatter.timeZone = .current
                let dateTimeString = dateFormatter.string(from: Date())

                TelemetryDeck.signal(
                    "LiveActivity.pushTokenReceived",
                    parameters: [
                        "activityIdPrefix": activityIdPrefix,
                        "activityState": currentState.telemetryName,
                        "totalActivities": "\(Activity<ReadingAttributes>.activities.count)",
                        "dateTime": dateTimeString
                    ]
                )

                await sendStartLiveActivity(token: tokenString)
            }
        }

        // Store a task that waits for state changes and cancels the token task when done
        observationTasks[activity.id] = Task {
            await stateTask.value
            tokenTask.cancel()
        }
    }

    private func sendStartLiveActivity(token: String) async {
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

        do {
            _ = try await URLSession.shared.data(for: request)
            TelemetryDeck.signal("LiveActivity.sentToken")
        } catch {
            TelemetryDeck.signal("LiveActivity.failedToSendToken")
        }
    }

    private func sendEndLiveActivity() async {
        guard let username = Keychain.shared.username else { return }

        let payload = EndLiveActivityRequest(username: username)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        var request = URLRequest(url: Backend.current.url(for: "end-live-activity"))
        request.httpMethod = "POST"
        request.httpBody = try! encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            _ = try await URLSession.shared.data(for: request)
            TelemetryDeck.signal("LiveActivity.sentEnd")
        } catch {
            TelemetryDeck.signal("LiveActivity.failedToSendEnd")
        }
    }
}

extension ActivityState {
    var telemetryName: String {
        switch self {
        case .active:
            "active"
        case .ended:
            "ended"
        case .dismissed:
            "dismissed"
        case .stale:
            "stale"
        case .pending:
            "pending"
        @unknown default:
            "unknown"
        }
    }
}
