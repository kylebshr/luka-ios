//
//  StartLiveActivityIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 10/17/25.
//

import ActivityKit
import AppIntents
import Defaults
import Dexcom
import Foundation
import KeychainAccess
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

    static let title: LocalizedStringResource = "Start Live Activity"
    static let description = IntentDescription("Monitor glucose readings in a Live Activity.")

    private let username = Keychain.shared.username
    private let password = Keychain.shared.password
    private let accountID = Keychain.shared.accountID
    private let sessionID = Keychain.shared.sessionID
    private let accountLocation: AccountLocation? = Defaults[.accountLocation]

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

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.disabled
        }

        let client = DexcomHelper.createService(
            username: username,
            password: password,
            existingAccountID: accountID,
            existingSessionID: sessionID,
            accountLocation: accountLocation
        )

        let range: GraphRange = .threeHours
        let readings = try await client
            .getGlucoseReadings(duration: .init(value: range.timeInterval, unit: .seconds))
            .sorted { $0.date < $1.date }

        let attributes = ReadingAttributes(range: range)
        let initialState = LiveActivityState(readings: readings, range: range)

        _ = try Activity.request(
            attributes: attributes,
            content: .init(
                state: initialState,
                staleDate: initialState.c?.date.addingTimeInterval(10 * 60)
            ),
            pushType: .token
        )

        TelemetryDeck.signal(
            "LiveActivity.started",
            parameters: ["source": source]
        )

        return .result()
    }
}
