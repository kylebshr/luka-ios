//
//  LukaGraphWidget.swift
//  Luka
//
//  Created by Kyle Bashour on 5/1/24.
//

import WidgetKit
import SwiftUI
import Dexcom

struct GraphWidget: Widget {
    let kind: String = "GlimpseChartWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            provider: GraphTimelineProvider()
        ) { entry in
            GraphWidgetView(entry: entry)
        }
        .supportedFamilies(families)
        .configurationDisplayName("Reading Graph")
    }

    private var families: [WidgetFamily] {
        #if os(watchOS)
        [
            .accessoryRectangular,
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
        ]
        #endif
    }
}

#Preview(as: .accessoryRectangular) {
    GraphWidget()
} timeline: {
    GlucoseEntry<GlucoseGraphEntryData>(
        date: .now,
        widgetURL: nil,
        state: .reading(
            .init(
                configuration: GraphWidgetConfiguration(graphRange: .threeHours),
                current: .placeholder,
                history: .placeholder
            )
        )
    )
    GlucoseEntry<GlucoseGraphEntryData>(
        date: .now.addingTimeInterval(80),
        widgetURL: nil,
        state: .reading(
            .init(
                configuration: GraphWidgetConfiguration(),
                current: .placeholder,
                history: .placeholder
            )
        )
    )
    GlucoseEntry<GlucoseGraphEntryData>(
        date: .now.addingTimeInterval(300),
        widgetURL: nil,
        state: .reading(
            .init(
                configuration: GraphWidgetConfiguration(),
                current: .placeholder,
                history: .placeholder
            )
        )
    )
    GlucoseEntry<GlucoseGraphEntryData>(
        date: .now.addingTimeInterval(60 * 30),
        widgetURL: nil,
        state: .reading(
            .init(
                configuration: GraphWidgetConfiguration(),
                current: .placeholder,
                history: .placeholder
            )
        )
    )
    GlucoseEntry<GlucoseGraphEntryData>(date: .now, widgetURL: nil, state: .error(.failedToLoad))
    GlucoseEntry<GlucoseGraphEntryData>(date: .now, widgetURL: nil, state: .error(.noRecentReadings))
    GlucoseEntry<GlucoseGraphEntryData>(date: .now, widgetURL: nil, state: .error(.loggedOut))
}

#if os(iOS)
private func previewGraphAccount(
    _ name: String,
    offset: Int,
    configuration: GraphWidgetConfiguration = GraphWidgetConfiguration(graphRange: .threeHours)
) -> GraphTimelineProvider.Entry.Account {
    // Shift the sample day so each account's graph looks different.
    let history = Array([GlucoseReading].placeholder.dropLast(offset)).enumerated().map { index, reading in
        GlucoseReading(
            value: reading.value,
            trend: reading.trend,
            date: [GlucoseReading].placeholder[index + offset].date.addingTimeInterval(4 * 60)
        )
    }
    return .init(
        name: name,
        state: .reading(.init(configuration: configuration, current: history.last!, history: history))
    )
}

private var previewGraphAccounts: [GraphTimelineProvider.Entry.Account] {
    [
        previewGraphAccount("Alex", offset: 0),
        previewGraphAccount("Sam", offset: 110),
        previewGraphAccount("Jordan", offset: 160),
    ]
}

#Preview("Two accounts", as: .systemMedium) {
    GraphWidget()
} timeline: {
    GlucoseEntry(date: .now, widgetURL: nil, accounts: Array(previewGraphAccounts.prefix(2)))
    GlucoseEntry(date: .now, widgetURL: nil, accounts: [previewGraphAccounts[0], .init(name: "Sam", state: .error(.noRecentReadings))])
}

#Preview("Three accounts", as: .systemLarge) {
    GraphWidget()
} timeline: {
    GlucoseEntry(date: .now, widgetURL: nil, accounts: previewGraphAccounts)
    GlucoseEntry(date: .now, widgetURL: nil, accounts: Array(previewGraphAccounts.prefix(2)))
    GlucoseEntry(
        date: .now,
        widgetURL: nil,
        accounts: Array(previewGraphAccounts.prefix(2)) + [.init(name: "Jordan", state: .error(.failedToLoad))]
    )
}
#endif
