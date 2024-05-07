//
//  GlimpseWidget.swift
//  GlimpseWidget
//
//  Created by Kyle Bashour on 4/24/24.
//

import WidgetKit
import SwiftUI
import Dexcom

struct GlimpseReadingWidget: Widget {
    let kind: String = "GlimpseReadingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: ReadingTimelineProvider()
        ) { entry in
            ReadingWidgetView(entry: entry)
        }
        .supportedFamilies(families)
        .configurationDisplayName("Current Reading")
    }

    private var families: [WidgetFamily] {
        #if os(watchOS)
        [
            .accessoryInline,
            .accessoryCircular,
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
        ]
        #endif
    }
}

#Preview(as: .accessoryRectangular) {
    GlimpseReadingWidget()
} timeline: {
    GlucoseEntry<GlucoseReading>(date: .now, state: .reading(.placeholder))
    GlucoseEntry<GlucoseReading>(
        date: .now.addingTimeInterval(150),
        state: .reading(.init(value: 240, trend: .doubleDown, date: .now))
    )
    GlucoseEntry<GlucoseReading>(
        date: .now.addingTimeInterval(800),
        state: .reading(.init(value: 45, trend: .fortyFiveUp, date: .now))
    )
    GlucoseEntry<GlucoseReading>(
        date: .now.addingTimeInterval(30 * 60),
        state: .reading(.init(value: 240, trend: .doubleDown, date: .now))
    )
    GlucoseEntry<GlucoseReading>(date: .now, state: .error(.failedToLoad))
    GlucoseEntry<GlucoseReading>(date: .now, state: .error(.noRecentReadings))
    GlucoseEntry<GlucoseReading>(date: .now, state: .error(.loggedOut))
}
