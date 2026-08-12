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
            .accessoryCorner,
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
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .reading(.placeholder))
    GlucoseEntry<GlucoseDeltaEntryData>(
        date: .now.addingTimeInterval(150),
        widgetURL: nil,
        state: .reading(.placeholder(.init(value: 240, trend: .doubleDown, date: .now), delta: -12))
    )
    GlucoseEntry<GlucoseDeltaEntryData>(
        date: .now.addingTimeInterval(800),
        widgetURL: nil,
        state: .reading(.placeholder(.init(value: 45, trend: .fortyFiveUp, date: .now), delta: 4))
    )
    GlucoseEntry<GlucoseDeltaEntryData>(
        date: .now.addingTimeInterval(30 * 60),
        widgetURL: nil,
        state: .reading(.placeholder(.init(value: 240, trend: .doubleDown, date: .now), delta: -12))
    )
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .error(.failedToLoad))
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .error(.noRecentReadings))
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .error(.loggedOut))
}
