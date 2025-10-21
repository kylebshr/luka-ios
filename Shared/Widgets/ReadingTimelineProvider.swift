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
    typealias Entry = GlucoseEntry<GlucoseReading>

    let delegate = DexcomDelegate()

    func placeholder(in context: Context) -> Entry {
        GlucoseEntry(date: .now, widgetURL: nil, state: .reading(.placeholder))
    }
    
    func snapshot(for configuration: ReadingWidgetConfiguration, in context: Context) async -> Entry {
        await Entry(date: .now, widgetURL: configuration.url, state: makeState(for: configuration))
    }

    func timeline(for configuration: ReadingWidgetConfiguration, in context: Context) async -> Timeline<Entry> {
        let state = await makeState(for: configuration)
        recordSessionIfNeeded()
        return buildTimeline(for: state, widgetURL: configuration.url)
    }

    func recommendations() -> [AppIntentRecommendation<ReadingWidgetConfiguration>] {
        [AppIntentRecommendation(intent: ReadingWidgetConfiguration(), description: "Current Reading")]
    }

    private func makeState(for configuration: ReadingWidgetConfiguration) async -> Entry.State {
        guard let username = Keychain.shared.username, let password = Keychain.shared.password, let accountLocation = Defaults[.accountLocation] else {
            return .error(.loggedOut)
        }

        let client = makeClient(
            username: username,
            password: password,
            accountLocation: accountLocation
        )

        do {
            if let current = try await client.getLatestGlucoseReading(), Date.now.timeIntervalSince(current.date) < 60 * 15 {
                return .reading(current)
            } else {
                return .error(.noRecentReadings)
            }
        } catch {
            return .error(.failedToLoad)
        }
    }
}
