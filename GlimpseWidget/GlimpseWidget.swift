//
//  GlimpseWidget.swift
//  GlimpseWidget
//
//  Created by Kyle Bashour on 4/24/24.
//

import WidgetKit
import SwiftUI
import Dexcom

struct GlimpseWidget: Widget {
    let kind: String = "GlimpseWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            GlimpseWidgetEntryView(entry: entry)
        }
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

#Preview(as: .accessoryCircular) {
    GlimpseWidget()
} timeline: {
    GlucoseEntry(date: .now, state: .reading(.placeholder))
    GlucoseEntry(date: .now, state: .reading(.init(value: 50, trend: .fortyFiveUp, date: .now - 60)))
    GlucoseEntry(date: .now.addingTimeInterval(10 * 60), state: .reading(.init(value: 60, trend: .doubleDown, date: .now - 400)))
    GlucoseEntry(date: .now.addingTimeInterval(15 * 60), state: .reading(.init(value: 183, trend: .doubleUp, date: .now - 900)))
    GlucoseEntry(date: .now.addingTimeInterval(20 * 60), state: .reading(.init(value: 183, trend: .doubleUp, date: .now - 900)))
    GlucoseEntry(date: .now, state: .error(.failedToLoad))
    GlucoseEntry(date: .now, state: .error(.noRecentReadings))
    GlucoseEntry(date: .now, state: .error(.loggedOut))
}
