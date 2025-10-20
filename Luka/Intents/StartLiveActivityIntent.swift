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
    static var description = IntentDescription("Monitor Glucose Readings in a Live Activity")

    private var username = Keychain.shared.username
    private var password = Keychain.shared.password
    private var accountLocation: AccountLocation? = Defaults[.accountLocation]

    init() {}

    func perform() async throws -> some IntentResult {
        guard let username, let password, let accountLocation else {
            throw LiveActivityError.loggedOut
        }

        for activity in Activity<ReadingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let client = DexcomClient(
                username: username,
                password: password,
                accountLocation: accountLocation
            )

            let (accountID, sessionID) = try await client.createSession()
            let readings = try await client.getGlucoseReadings()
                .sorted { $0.date < $1.date }

            let attributes = ReadingAttributes()
            let initialState = LiveActivityState(
                c: readings.last,
                h: Array(readings.suffix(12 * 6)).toLiveActivityReadings()
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
                    accountID: accountID,
                    sessionID: sessionID,
                    accountLocation: accountLocation
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
        accountID: UUID,
        sessionID: UUID,
        accountLocation: AccountLocation
    ) {
        Task {
            for await state in activity.activityStateUpdates {
                print(state)
            }
        }

        Task {
            for await token in activity.pushTokenUpdates {
                let token = token.map { String(format: "%02x", $0) }.joined()
                await sendStartLiveActivity(
                    token: token,
                    accountID: accountID,
                    sessionID: sessionID,
                    accountLocation: accountLocation
                )
            }
        }
    }

    private func sendStartLiveActivity(
        token: String,
        accountID: UUID,
        sessionID: UUID,
        accountLocation: AccountLocation
    ) async {
        let payload = StartLiveActivityRequest(
            pushToken: token,
            environment: .current,
            accountID: accountID,
            sessionID: sessionID,
            accountLocation: accountLocation,
            durationHours: 6
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        var request = URLRequest(url: URL(string: "https://luka-vapor.fly.dev/start-live-activity")!)
        request.httpMethod = "POST"
        request.httpBody = try! encoder.encode(payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print(data, response)
        } catch {
            print(error)
        }
    }
}
