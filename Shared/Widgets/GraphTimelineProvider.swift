//
//  TimelineProvider.swift
//  Luka
//
//  Created by Kyle Bashour on 4/24/24.
//

import WidgetKit
import Dexcom
import Defaults

struct GraphTimelineProvider: AppIntentTimelineProvider, DexcomTimelineProvider {
    typealias Entry = GlucoseEntry<GlucoseGraphEntryData>
    static let kind = AccountWidgetKind.graph

    func placeholder(in context: Context) -> Entry {
        GlucoseEntry(
            date: .now,
            widgetURL: nil,
            state: .reading(
                GlucoseGraphEntryData(
                    configuration: GraphWidgetConfiguration(),
                    current: GlucoseReading.placeholder,
                    history: []
                )
            )
        )
    }

    func snapshot(for configuration: GraphWidgetConfiguration, in context: Context) async -> Entry {
        let accounts = await makeAccounts(for: configuration, in: context)
        return GlucoseEntry(date: .now, widgetURL: configuration.app.url, accounts: accounts)
    }

    func timeline(for configuration: GraphWidgetConfiguration, in context: Context) async -> Timeline<Entry> {
        let accounts = await makeAccounts(for: configuration, in: context)
        return buildTimeline(for: accounts, widgetURL: configuration.app.url)
    }

    func recommendations() -> [AppIntentRecommendation<GraphWidgetConfiguration>] {
        #if os(watchOS)
        // watchOS 26 and later provide an interface for configuring widgets and
        // complications, so return an empty array to let people configure them.
        if #available(watchOS 26.0, *) {
            return []
        }
        #endif
        return GraphRange.allCases.map {
            let configuration = GraphWidgetConfiguration(graphRange: $0)
            return AppIntentRecommendation(intent: configuration, description: $0.abbreviatedName + " Graph")
        }
    }

    private func makeAccounts(for configuration: GraphWidgetConfiguration, in context: Context) async -> [Entry.Account] {
        let duration = Measurement<UnitDuration>(value: configuration.graphRange.timeInterval, unit: .seconds)
        return await makeAccounts(for: configuration, family: context.family) { client in
            try await client.getGraphReadings(duration: duration)
        } makeState: { readings in
            if let current = readings.last, Date.now.timeIntervalSince(current.date) < 60 * 15 {
                .reading(
                    GlucoseGraphEntryData(
                        configuration: configuration,
                        current: current,
                        history: readings
                    )
                )
            } else {
                .error(.noRecentReadings)
            }
        }
    }
}
