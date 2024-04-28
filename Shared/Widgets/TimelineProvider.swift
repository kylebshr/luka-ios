//
//  TimelineProvider.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/24/24.
//

import WidgetKit
import Dexcom
import KeychainAccess

struct Provider: AppIntentTimelineProvider {
    class Delegate: DexcomClientDelegate {
        func didUpdateAccountID(_ accountID: UUID) {
            Keychain.shared.accountID = accountID
        }

        func didUpdateSessionID(_ sessionID: UUID) {
            Keychain.shared.sessionID = sessionID
        }
    }

    private let delegate = Delegate()

    func placeholder(in context: Context) -> GlucoseEntry {
        GlucoseEntry(date: Date(), state: .reading(.placeholder))
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> GlucoseEntry {
        let state = await makeState()
        return GlucoseEntry(date: Date(), state: state)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<GlucoseEntry> {
        let state = await makeState()

        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!

        switch state {
        case .error:
            return Timeline(entries: [GlucoseEntry(date: .now, state: state)], policy: .after(refreshDate))
        case .reading(let glucoseReading):
            let entries = (1...20).map {
                let date = Calendar.current.date(byAdding: .minute, value: $0, to: currentDate)!
                return GlucoseEntry(date: date, state: state)
            }

            let refreshDate = Calendar.current.date(byAdding: .minute, value: 11, to: glucoseReading.date)!
            return Timeline(entries: entries, policy: .after(refreshDate))
        }
    }

    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        return [
            AppIntentRecommendation(intent: ConfigurationAppIntent(), description: "Default"),
        ]
    }

    func makeState() async -> GlucoseEntry.State {
        guard let username = Keychain.shared.username, let password = Keychain.shared.password else {
            return .error(.loggedOut)
        }

        let client = DexcomClient(
            username: username,
            password: password,
            existingAccountID: Keychain.shared.accountID,
            existingSessionID: Keychain.shared.sessionID,
            outsideUS: UserDefaults.shared.outsideUS
        )

        client.delegate = delegate

        do {
            if let reading = try await client.getCurrentGlucoseReading() {
                return .reading(reading)
            } else {
                return .error(.noRecentReadings)
            }
        } catch {
            return .error(.failedToLoad)
        }
    }
}

struct GlucoseEntry: TimelineEntry {
    enum State {
        case error(Error)
        case reading(GlucoseReading)
    }

    enum Error {
        case loggedOut
        case noRecentReadings
        case failedToLoad
    }

    let date: Date
    let state: State

    var isExpired: Bool {
        date.timeIntervalSince(.now) > 15 * 60
    }
}

extension GlucoseReading {
    static let placeholder = GlucoseReading(value: 104, trend: .flat, date: .now)
}

extension GlucoseEntry.Error {
    var buttonImage: String {
        switch self {
        case .loggedOut:
            "arrow.up.right"
        case .failedToLoad, .noRecentReadings:
            "arrow.circlepath"
        }
    }

    var buttonText: String {
        switch self {
        case .loggedOut:
            "Sign In"
        case .failedToLoad, .noRecentReadings:
            "Reload"
        }
    }

    var image: String {
        switch self {
        case .loggedOut:
            "person.slash"
        case .failedToLoad:
            "wifi.slash"
        case .noRecentReadings:
            "icloud.slash"
        }
    }
}
