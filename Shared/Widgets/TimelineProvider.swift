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
        case .loggedOut:
            return Timeline(entries: [GlucoseEntry(date: .now, state: state)], policy: .after(refreshDate))
        case .reading(let glucoseReading):
            if let glucoseReading {
                let entries = (1...20).map {
                    let date = Calendar.current.date(byAdding: .minute, value: $0, to: currentDate)!
                    return GlucoseEntry(date: date, state: state)
                }

                let refreshDate = Calendar.current.date(byAdding: .minute, value: 11, to: glucoseReading.date)!
                return Timeline(entries: entries, policy: .after(refreshDate))
            } else {
                return Timeline(entries: [GlucoseEntry(date: .now, state: state)], policy: .after(refreshDate))
            }
        }
    }

    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        return [
            AppIntentRecommendation(intent: ConfigurationAppIntent(), description: "Default"),
        ]
    }

    func makeState() async -> GlucoseEntry.State {
        guard let username = Keychain.shared.username, let password = Keychain.shared.password else {
            return .loggedOut
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
            return try await .reading(client.getCurrentGlucoseReading())
        } catch {
            return .reading(nil)
        }
    }
}

struct GlucoseEntry: TimelineEntry {
    enum State {
        case loggedOut
        case reading(GlucoseReading?)
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
