//
//  ReloadWidgetIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 10/17/25.
//

import Foundation
import Defaults
import KeychainAccess
import AppIntents
import ActivityKit
@preconcurrency import Dexcom
import TelemetryDeck

extension DexcomError: @retroactive CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: message ?? localizedDescription)
    }
}

struct StartLiveActivityIntent: LiveActivityIntent {
    enum LiveActivityError: Error, CustomLocalizedStringResourceConvertible {
        case disabled
        case loggedOut

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .disabled:
                "Live Activities are disabled."
            case .loggedOut:
                "You’re not logged in."
            }
        }
    }

    static var title: LocalizedStringResource = "Start Live Activity"
    static var description = IntentDescription("Monitor glucose readings in a Live Activity.")

    private var username = Keychain.shared.username
    private var password = Keychain.shared.password
    private var accountLocation: AccountLocation? = Defaults[.accountLocation]

    private var source: String = "none"

    init() {}

    init(source: String) {
        self.source = source
    }

    func perform() async throws -> some IntentResult {
        guard let username, let password, let accountLocation else {
            throw LiveActivityError.loggedOut
        }

        for activity in Activity<ReadingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let client = DexcomHelper.createService(
                username: username,
                password: password,
                accountLocation: accountLocation
            )

            let range: GraphRange = .threeHours

            let (accountID, sessionID) = try await client.createSession()
            let readings = try await client
                .getGlucoseReadings(duration: .init(value: range.timeInterval, unit: .seconds))
                .sorted { $0.date < $1.date }

            let attributes = ReadingAttributes(range: range)
            let initialState = LiveActivityState(
                c: readings.last,
                h: readings.toLiveActivityReadings()
            )

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(
                        state: initialState,
                        staleDate: initialState.c?.date.addingTimeInterval(10 * 60)
                    ),
                    pushType: .token
                )

                observeActivityUpdates(
                    for: activity,
                    username: username,
                    accountID: accountID,
                    sessionID: sessionID,
                    accountLocation: accountLocation,
                    range: range
                )

                TelemetryDeck.signal(
                    "LiveActivity.started",
                    parameters: ["source": source]
                )

                return .result()
            } catch {
                print(error)
                throw error
            }
        } else {
            throw LiveActivityError.disabled
        }
    }

    private func observeActivityUpdates(
        for activity: Activity<ReadingAttributes>,
        username: String,
        accountID: UUID,
        sessionID: UUID,
        accountLocation: AccountLocation,
        range: GraphRange
    ) {
        Task {
            for await state in activity.activityStateUpdates {
                switch state {
                case .dismissed:
                    if let token = activity.pushToken {
                        let token = token.map { String(format: "%02x", $0) }.joined()
                        await sendEndLiveActivity(token: token)
                    }
                case .active, .pending, .stale, .ended:
                    break
                @unknown default:
                    break
                }
            }
        }

        Task {
            for await token in activity.pushTokenUpdates {
                let token = token.map { String(format: "%02x", $0) }.joined()
                await sendStartLiveActivity(
                    token: token,
                    username: username,
                    accountID: accountID,
                    sessionID: sessionID,
                    accountLocation: accountLocation,
                    range: range
                )
            }
        }
    }

    private func sendStartLiveActivity(
        token: String,
        username: String,
        accountID: UUID,
        sessionID: UUID,
        accountLocation: AccountLocation,
        range: GraphRange
    ) async {
        guard username != DexcomHelper.mockEmail else {
            return
        }

        let payload = StartLiveActivityRequest(
            pushToken: token,
            environment: .current,
            accountID: accountID,
            sessionID: sessionID,
            accountLocation: accountLocation,
            duration: range.timeInterval
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        var request = URLRequest(url: URL(string: "https://a1c.dev/start-live-activity")!)
        request.httpMethod = "POST"
        request.httpBody = try! encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            TelemetryDeck.signal("LiveActivity.sentToken")
        } catch {
            TelemetryDeck.signal("LiveActivity.failedToSendToken")
        }
    }

    private func sendEndLiveActivity(token: String) async {
        let payload = EndLiveActivityRequest(pushToken: token)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        var request = URLRequest(url: URL(string: "https://a1c.dev/end-live-activity")!)
        request.httpMethod = "POST"
        request.httpBody = try! encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            TelemetryDeck.signal("LiveActivity.sentEnd")
        } catch {
            TelemetryDeck.signal("LiveActivity.failedToSendEnd")
        }
    }
}
