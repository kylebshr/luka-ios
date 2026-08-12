//
//  ReadingDeltaWidget.swift
//  Luka
//
//  Created by Kyle Bashour on 08/12/26.
//

import WidgetKit
import SwiftUI
import Dexcom

/// A rectangular accessory widget laid out like the small Live Activity: the
/// reading, the change since the previous one, and how long ago it arrived.
/// Available as a watch complication and on the iOS Lock Screen.
struct ReadingDeltaWidget: Widget {
    let kind: String = "LukaReadingDeltaWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            provider: ReadingTimelineProvider()
        ) { entry in
            ReadingDeltaWidgetView(entry: entry)
                .widgetURL(entry.widgetURL)
        }
        .supportedFamilies([.accessoryRectangular])
        .configurationDisplayName("Reading & Delta")
    }
}

#Preview(as: .accessoryRectangular) {
    ReadingDeltaWidget()
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
        state: .reading(.placeholder(.init(value: 108, trend: .flat, date: .now), delta: 0))
    )
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .error(.failedToLoad))
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .error(.noRecentReadings))
    GlucoseEntry<GlucoseDeltaEntryData>(date: .now, widgetURL: nil, state: .error(.loggedOut))
}
