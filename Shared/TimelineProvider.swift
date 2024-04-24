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
            UserDefaults.shared.accountID = accountID
        }

        func didUpdateSessionID(_ sessionID: UUID) {
            UserDefaults.shared.sessionID = sessionID
        }
    }

    private let delegate = Delegate()

    func placeholder(in context: Context) -> GlucoseEntry {
        GlucoseEntry(date: Date(), state: .reading(.placeholder))
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> GlucoseEntry {
        let state = await makeState(outsideUS: configuration.outsideUS)
        return GlucoseEntry(date: Date(), state: state)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<GlucoseEntry> {
        let state = await makeState(outsideUS: configuration.outsideUS)

        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!

        switch state {
        case .loggedOut:
            return Timeline(entries: [GlucoseEntry(date: .now, state: state)], policy: .after(refreshDate))
        case .reading(let glucoseReading):
            if glucoseReading != nil {
                let entries = (1...15).map {
                    let date = Calendar.current.date(byAdding: .minute, value: $0, to: currentDate)!
                    return GlucoseEntry(date: date, state: state)
                }

                let expired = GlucoseEntry(
                    date: Calendar.current.date(byAdding: .minute, value: 20, to: currentDate)!,
                    state: state
                )

                return Timeline(entries: entries + [expired], policy: .after(refreshDate))
            } else {
                return Timeline(entries: [GlucoseEntry(date: .now, state: state)], policy: .after(refreshDate))
            }
        }
    }

    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        let outsideUS = ConfigurationAppIntent()
        outsideUS.outsideUS = true

        return [
            AppIntentRecommendation(intent: ConfigurationAppIntent(), description: "Inside US"),
            AppIntentRecommendation(intent: outsideUS, description: "Outside US"),
        ]
    }

    func makeState(outsideUS: Bool) async -> GlucoseEntry.State {
        guard let username = UserDefaults.shared.username, let password = UserDefaults.shared.password else {
            return .loggedOut
        }

        let client = DexcomClient(
            username: username,
            password: password,
            existingAccountID: UserDefaults.shared.accountID,
            existingSessionID: UserDefaults.shared.sessionID,
            outsideUS: outsideUS
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
