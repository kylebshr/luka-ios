//
//  ReadingDeltaWidget.swift
//  Luka
//
//  Created by Kyle Bashour on 08/12/26.
//

import WidgetKit
import SwiftUI
import Dexcom

/// A rectangular watch complication laid out like the small Live Activity: the
/// reading, the change since the previous one, and how long ago it arrived.
struct ReadingDeltaWidget: Widget {
    let kind: String = "LukaReadingDeltaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            provider: ReadingDeltaTimelineProvider()
        ) { entry in
            ReadingDeltaWidgetView(entry: entry)
                .widgetURL(entry.widgetURL)
        }
        .supportedFamilies([.accessoryRectangular])
        .configurationDisplayName("Reading & Change")
    }
}

#Preview(as: .accessoryRectangular) {
    ReadingDeltaWidget()
} timeline: {
    GlucoseEntry<GlucoseDeltaEntryData>(
        date: .now,
        widgetURL: nil,
        state: .reading(.init(current: .placeholder, previous: nil))
    )
    GlucoseEntry<GlucoseDeltaEntryData>(
        date: .now.addingTimeInterval(150),
        widgetURL: nil,
        state: .reading(
            .init(
                current: .init(value: 240, trend: .doubleDown, date: .now),
                previous: .init(value: 252, trend: .doubleDown, date: .now.addingTimeInterval(-5 * 60))
            )
        )
    )
    GlucoseEntry<GlucoseDeltaEntryData>(
        date: .now.addingTimeInterval(800),
        widgetURL: nil,
        state: .reading(
            .init(
                current: .init(value: 45, trend: .fortyFiveUp, date: .now),
                previous: .init(value: 41, trend: .fortyFiveUp, date: .now.addingTimeInterval(-5 * 60))
            )
        )
    )
    GlucoseEntry<GlucoseDeltaEntryData>(
        date: .now.addingTimeInterval(30 * 60),
        widgetURL: nil,
        state: .reading(
            .init(
                current: .init(value: 108, trend: .flat, date: .now),
                previous: .init(value: 108, trend: .flat, date: .now.addingTimeInterval(-5 * 60))
            )
        )
    )
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .error(.failedToLoad))
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .error(.noRecentReadings))
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .error(.loggedOut))
}
