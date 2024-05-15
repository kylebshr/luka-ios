//
//  LukaWidget.swift
//  LukaWidget
//
//  Created by Kyle Bashour on 4/24/24.
//

import WidgetKit
import SwiftUI
import Dexcom

struct ReadingWidget: Widget {
    let kind: String = "GlimpseReadingWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            provider: ReadingTimelineProvider()
        ) { entry in
            ReadingWidgetView(entry: entry)
                .widgetURL(entry.widgetURL)
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
            .accessoryRectangular,
        ]
        #endif
    }
}

#Preview(as: .accessoryRectangular) {
    ReadingWidget()
} timeline: {
    GlucoseEntry<GlucoseReading>(date: .now, widgetURL: nil, state: .reading(.placeholder))
    GlucoseEntry<GlucoseReading>(
        date: .now.addingTimeInterval(150),
        widgetURL: nil,
        state: .reading(.init(value: 240, trend: .doubleDown, date: .now))
    )
    GlucoseEntry<GlucoseReading>(
        date: .now.addingTimeInterval(800),
        widgetURL: nil,
        state: .reading(.init(value: 45, trend: .fortyFiveUp, date: .now))
    )
    GlucoseEntry<GlucoseReading>(
        date: .now.addingTimeInterval(30 * 60),
        widgetURL: nil,
        state: .reading(.init(value: 240, trend: .doubleDown, date: .now))
    )
    GlucoseEntry<GlucoseReading>(date: .now, widgetURL: nil, state: .error(.failedToLoad))
    GlucoseEntry<GlucoseReading>(date: .now, widgetURL: nil, state: .error(.noRecentReadings))
    GlucoseEntry<GlucoseReading>(date: .now, widgetURL: nil, state: .error(.loggedOut))
}
