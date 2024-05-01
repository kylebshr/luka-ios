//
//  TimelineProvider.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/24/24.
//

import WidgetKit
import Dexcom
import KeychainAccess

struct ChartTimelineProvider: AppIntentTimelineProvider, DexcomTimelineProvider {
    typealias Entry = GlucoseEntry<ChartGlucoseData>

    let delegate = DexcomDelegate()

    func placeholder(in context: Context) -> Entry {
        GlucoseEntry(
            date: .now,
            state: .reading(
                ChartGlucoseData(
                    configuration: ChartWidgetConfiguration(),
                    current: GlucoseReading.placeholder,
                    history: []
                )
            )
        )
    }

    func snapshot(for configuration: ChartWidgetConfiguration, in context: Context) async -> Entry {
        let state = await makeState(for: configuration)
        return GlucoseEntry(date: .now, state: state)
    }

    func timeline(for configuration: ChartWidgetConfiguration, in context: Context) async -> Timeline<Entry> {
        let state = await makeState(for: configuration)
        return buildTimeline(for: state)
    }

    func recommendations() -> [AppIntentRecommendation<ChartWidgetConfiguration>] {
        ChartRange.allCases.map {
            let configuration = ChartWidgetConfiguration(chartRange: $0)
            return AppIntentRecommendation(intent: configuration, description: $0.abbreviatedName + " Chart")
        }
    }

    private func makeState(for configuration: ChartWidgetConfiguration) async -> Entry.State {
        guard let username = Keychain.shared.username, let password = Keychain.shared.password else {
            return .error(.loggedOut)
        }

        let client = makeClient(username: username, password: password)

        do {
            let readings = try await client.getGlucoseReadingsWithCache(maxCount: nil)
            if let current = readings.last, Date.now.timeIntervalSince(current.date) < 60 * 15 {
                return .reading(
                    ChartGlucoseData(
                        configuration: configuration,
                        current: current,
                        history: readings.map(GlucoseChartMark.init)
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
