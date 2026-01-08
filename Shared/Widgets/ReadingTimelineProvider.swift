//
//  ReadingTimelineProvider.swift
//  Luka
//
//  Created by Kyle Bashour on 5/1/24.
//

import WidgetKit
import Dexcom
import KeychainAccess
import Defaults

struct ReadingTimelineProvider: AppIntentTimelineProvider, DexcomTimelineProvider {
    typealias Entry = GlucoseEntry<GlucoseReadingWithDelta>

    let delegate = KeychainDexcomDelegate()

    func placeholder(in context: Context) -> Entry {
        GlucoseEntry(date: .now, widgetURL: nil, state: .reading(GlucoseReadingWithDelta(current: .placeholder, previous: nil)))
    }

    func snapshot(for configuration: ReadingWidgetConfiguration, in context: Context) async -> Entry {
        await Entry(date: .now, widgetURL: configuration.url, state: makeState(for: configuration))
    }

    func timeline(for configuration: ReadingWidgetConfiguration, in context: Context) async -> Timeline<Entry> {
        let state = await makeState(for: configuration)
        return buildTimeline(for: state, widgetURL: configuration.url)
    }

    func recommendations() -> [AppIntentRecommendation<ReadingWidgetConfiguration>] {
        [AppIntentRecommendation(intent: ReadingWidgetConfiguration(), description: "Current Reading")]
    }

    private func makeState(for configuration: ReadingWidgetConfiguration) async -> Entry.State {
        guard let username = Keychain.shared.username, let password = Keychain.shared.password, let accountLocation = Defaults[.accountLocation] else {
            return .error(.loggedOut)
        }

        let client = await makeClient(
            username: username,
            password: password,
            accountLocation: accountLocation
        )

        do {
            // Fetch 2 readings to enable delta calculation
            let readings = try await client.getGlucoseReadings(maxCount: 2).sorted { $0.date < $1.date }
            if let current = readings.last, Date.now.timeIntervalSince(current.date) < 60 * 15 {
                let previous = readings.count >= 2 ? readings[readings.count - 2] : nil
                return .reading(GlucoseReadingWithDelta(current: current, previous: previous))
            } else {
                return .error(.noRecentReadings)
            }
        } catch {
            return .error(.failedToLoad)
        }
    }
}
