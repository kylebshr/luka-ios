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

    let delegate = KeychainDexcomDelegate()

    func placeholder(in context: Context) -> Entry {
        GlucoseEntry(date: .now, widgetURL: nil, state: .reading(.placeholder))
    }
    
    func snapshot(for configuration: ReadingWidgetConfiguration, in context: Context) async -> Entry {
        await Entry(date: .now, widgetURL: configuration.url, state: makeState(for: configuration))
    }

    func timeline(for configuration: ReadingWidgetConfiguration, in context: Context) async -> Timeline<Entry> {
        let state = await makeState(for: configuration)
        return buildTimeline(for: state, widgetURL: configuration.url)
    }

    func recommendations() -> [AppIntentRecommendation<ReadingWidgetConfiguration>] {
        #if os(watchOS)
        // watchOS 26 and later provide an interface for configuring widgets and
        // complications, so return an empty array to let people configure them.
        if #available(watchOS 26.0, *) {
            return []
        }
        #endif
        return [AppIntentRecommendation(intent: ReadingWidgetConfiguration(), description: "Current Reading")]
    }

    private func makeState(for configuration: ReadingWidgetConfiguration) async -> Entry.State {
        guard let client = await makeModeClient() else {
            return .error(.loggedOut)
        }

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
