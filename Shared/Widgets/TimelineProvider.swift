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
        GlucoseEntry(
            configuration: ConfigurationAppIntent(),
            date: Date(),
            state: .reading(.placeholder, history: [])
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> GlucoseEntry {
        let state = await makeState()
        return GlucoseEntry(configuration: configuration, date: Date(), state: state)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<GlucoseEntry> {
        let state = await makeState()

        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!

        switch state {
        case .error:
            return Timeline(
                entries: [GlucoseEntry(
                    configuration: configuration,
                    date: .now,
                    state: state
                )],
                policy: .after(refreshDate)
            )
        case .reading(let reading, _):
            let entries = (1...20).map {
                let date = Calendar.current.date(byAdding: .minute, value: $0, to: currentDate)!
                return GlucoseEntry(configuration: configuration, date: date, state: state)
            }

            let refreshDate = Calendar.current.date(byAdding: .minute, value: 11, to: reading.date)!
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
            let readings = try await client.getGlucoseReadingsWithCache()
            if let latest = readings.last, Date.now.timeIntervalSince(latest.date) < 60 * 15 {
                return .reading(latest, history: readings)
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
        case reading(GlucoseReading, history: [GlucoseReading])
    }

    enum Error {
        case loggedOut
        case noRecentReadings
        case failedToLoad
    }

    let configuration: ConfigurationAppIntent
    let date: Date
    let state: State
    let targetUpperBound: Int = UserDefaults.shared.targetRangeUpperBound
    let targetLowerBound: Int = UserDefaults.shared.targetRangeLowerBound
    let chartUpperBound: Int = UserDefaults.shared.chartUpperBound

    var isExpired: Bool {
        switch state {
        case .error: false
        case .reading(let reading, _):
            Date.now.timeIntervalSince(reading.date) > 20 * 60
        }
    }

    var chartRangeTitle: String {
        configuration.chartRange.abbreviatedName
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

    var description: String {
        switch self {
        case .loggedOut:
            "No account"
        case .noRecentReadings:
            "No recent readings"
        case .failedToLoad:
            "Network error"
        }
    }
}
