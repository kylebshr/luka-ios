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

    let delegate = DexcomDelegate()

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
        recordSessionIfNeeded()
        return buildTimeline(for: state, widgetURL: configuration.app.url)
    }

    func recommendations() -> [AppIntentRecommendation<GraphWidgetConfiguration>] {
        GraphRange.allCases.map {
            let configuration = GraphWidgetConfiguration(graphRange: $0)
            return AppIntentRecommendation(intent: configuration, description: $0.abbreviatedName + " Graph")
        }
    }

    private func makeState(for configuration: GraphWidgetConfiguration) async -> Entry.State {
        guard let username = Keychain.shared.username, let password = Keychain.shared.password, let accountLocation = Defaults[.accountLocation] else {
            return .error(.loggedOut)
        }

        let client = makeClient(
            username: username,
            password: password,
            accountLocation: accountLocation
        )

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
