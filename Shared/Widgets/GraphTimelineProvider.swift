//
//  TimelineProvider.swift
//  Luka
//
//  Created by Kyle Bashour on 4/24/24.
//

import WidgetKit
import Dexcom
import KeychainAccess
import Defaults

struct GraphTimelineProvider: AppIntentTimelineProvider, DexcomTimelineProvider {
    typealias Entry = GlucoseEntry<GlucoseGraphEntryData>

    let delegate = KeychainDexcomDelegate()

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
        let state = await makeState(for: configuration)
        return GlucoseEntry(date: .now, widgetURL: configuration.app.url, state: state)
    }

    func timeline(for configuration: GraphWidgetConfiguration, in context: Context) async -> Timeline<Entry> {
        let state = await makeState(for: configuration)
        return buildTimeline(for: state, widgetURL: configuration.app.url)
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

    private func makeState(for configuration: GraphWidgetConfiguration) async -> Entry.State {
        guard let client = await makeModeClient() else {
            return .error(.loggedOut)
        }

        do {
            let readings = try await client.getGraphReadings(
                duration: .init(
                    value: configuration.graphRange.timeInterval,
                    unit: .seconds
                )
            )

            if let current = readings.last, Date.now.timeIntervalSince(current.date) < 60 * 15 {
                return .reading(
                    GlucoseGraphEntryData(
                        configuration: configuration,
                        current: current,
                        history: readings
                    )
                )
            } else {
                return .error(.noRecentReadings)
            }
        } catch {
            return .error(.failedToLoad)
        }
    }
}
