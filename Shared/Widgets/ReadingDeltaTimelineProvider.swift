//
//  ReadingDeltaTimelineProvider.swift
//  Luka
//
//  Created by Kyle Bashour on 08/12/26.
//

import WidgetKit
import Dexcom
import KeychainAccess
import Defaults

/// Loads the last few readings so the widget can show the change between the
/// two most recent ones. `ReadingTimelineProvider` only fetches the latest
/// reading, which isn't enough to compute a delta.
struct ReadingDeltaTimelineProvider: AppIntentTimelineProvider, DexcomTimelineProvider {
    typealias Entry = GlucoseEntry<GlucoseDeltaEntryData>

    let delegate = KeychainDexcomDelegate()

    func placeholder(in context: Context) -> Entry {
        GlucoseEntry(
            date: .now,
            widgetURL: nil,
            state: .reading(
                GlucoseDeltaEntryData(
                    current: .placeholder,
                    previous: nil
                )
            )
        )
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
        return [AppIntentRecommendation(intent: ReadingWidgetConfiguration(), description: "Reading & Change")]
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
            // Just enough history to find the reading before the current one;
            // anything older can't produce a meaningful delta anyway.
            let readings = try await client.getGraphReadings(
                duration: .init(value: 20, unit: .minutes)
            )

            guard let current = readings.last, Date.now.timeIntervalSince(current.date) < 60 * 15 else {
                return .error(.noRecentReadings)
            }

            return .reading(
                GlucoseDeltaEntryData(
                    current: current,
                    previous: readings.dropLast().last
                )
            )
        } catch DexcomClientError.noReadings {
            return .error(.noRecentReadings)
        } catch {
            return .error(.failedToLoad)
        }
    }
}
