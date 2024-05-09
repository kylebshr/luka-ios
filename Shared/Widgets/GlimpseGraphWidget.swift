//
//  GlimpseGraphWidget.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import WidgetKit
import SwiftUI
import Dexcom

struct GlimpseGraphWidget: Widget {
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
    GlimpseGraphWidget()
} timeline: {
    GlucoseEntry<GlucoseGraphEntryData>(
        date: .now,
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
