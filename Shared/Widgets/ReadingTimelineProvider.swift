//
//  ReadingTimelineProvider.swift
//  Luka
//
//  Created by Kyle Bashour on 5/1/24.
//

import WidgetKit
import Dexcom
import Defaults

struct ReadingTimelineProvider: AppIntentTimelineProvider, DexcomTimelineProvider {
    typealias Entry = GlucoseEntry<GlucoseReading>
    static let kind = AccountWidgetKind.reading

    func placeholder(in context: Context) -> Entry {
        GlucoseEntry(date: .now, widgetURL: nil, state: .reading(.placeholder))
    }
    
    func snapshot(for configuration: ReadingWidgetConfiguration, in context: Context) async -> Entry {
        await Entry(date: .now, widgetURL: configuration.url, accounts: makeAccounts(for: configuration, in: context))
    }

    func timeline(for configuration: ReadingWidgetConfiguration, in context: Context) async -> Timeline<Entry> {
        let accounts = await makeAccounts(for: configuration, in: context)
        return buildTimeline(for: accounts, widgetURL: configuration.url)
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

    private func makeAccounts(for configuration: ReadingWidgetConfiguration, in context: Context) async -> [Entry.Account] {
        await makeAccounts(for: configuration, family: context.family) { client in
            try await client.getLatestGlucoseReading()
        } makeState: { reading in
            if let reading, Date.now.timeIntervalSince(reading.date) < 60 * 15 {
                .reading(reading)
            } else {
                .error(.noRecentReadings)
            }
        }
    }
}
