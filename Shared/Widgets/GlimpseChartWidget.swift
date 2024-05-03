//
//  GlimpseChartWidget.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import WidgetKit
import SwiftUI
import Dexcom

struct GlimpseChartWidget: Widget {
    let kind: String = "GlimpseChartWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ChartWidgetConfiguration.self,
            provider: ChartTimelineProvider()
        ) { entry in
            ChartWidgetView(entry: entry)
        }
        .supportedFamilies(families)
        .configurationDisplayName("Reading Chart")
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
    GlimpseChartWidget()
} timeline: {
    GlucoseEntry<GlucoseChartEntryData>(
        date: .now,
        state: .reading(
            .init(
                configuration: ChartWidgetConfiguration(),
                current: .placeholder,
                history: .placeholder
            )
        )
    )
    GlucoseEntry<GlucoseChartEntryData>(
        date: .now.addingTimeInterval(60 * 30),
        state: .reading(
            .init(
                configuration: ChartWidgetConfiguration(),
                current: .placeholder,
                history: .placeholder
            )
        )
    )
    GlucoseEntry<GlucoseChartEntryData>(date: .now, state: .error(.failedToLoad))
    GlucoseEntry<GlucoseChartEntryData>(date: .now, state: .error(.noRecentReadings))
    GlucoseEntry<GlucoseChartEntryData>(date: .now, state: .error(.loggedOut))
}
