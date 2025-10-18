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

extension DexcomError: CustomLocalizedStringResourceConvertible {
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

        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let client = DexcomClient(
                username: username,
                password: password,
                accountLocation: accountLocation
            )

            let (accountID, sessionID) = try await client.createSession()
            let readings = try await client.getGlucoseReadings(maxCount: 12 * 6 + 1)

            let attributes = ReadingAttributes()
            let initialState = ReadingAttributes.ContentState(history: readings)

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(
                        state: initialState,
                        staleDate: initialState.history.last?.date.addingTimeInterval(10 * 60)
                    ),
                    pushType: .token
                )

                observeActivityUpdates(
                    for: activity,
                    accountID: accountID,
                    sessionID: sessionID
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
        sessionID: UUID
    ) {
        Task {
            for await token in activity.pushTokenUpdates {
                let token = token.map { String(format: "%02x", $0) }.joined()
                print(token)
            }
        }
    }
}
