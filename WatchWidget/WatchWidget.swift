//
//  WatchWidget.swift
//  WatchWidget
//
//  Created by Kyle Bashour on 4/23/24.
//

import WidgetKit
import SwiftUI
import Dexcom
import KeychainAccess

@main
struct WatchWidget: Widget {
    let kind: String = "WatchWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            GlimpseWidgetEntryView(entry: entry)
        }
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

#Preview(as: .accessoryCircular) {
    WatchWidget()
} timeline: {
    GlucoseEntry(date: .now, state: .reading(.placeholder, history: [.placeholder]))
//    GlucoseEntry(date: .now, state: .reading(.init(value: 60, trend: .fortyFiveUp, date: .now - 60)))
//    GlucoseEntry(date: .now, state: .reading(.init(value: 102, trend: .doubleDown, date: .now - 400)))
//    GlucoseEntry(date: .now, state: .reading(.init(value: 184, trend: .doubleDown, date: .now - 400)))
//    GlucoseEntry(date: .now.addingTimeInterval(20 * 60), state: .reading(.init(value: 183, trend: .doubleUp, date: .now - 900)))
    GlucoseEntry(date: .now, state: .error(.failedToLoad))
    GlucoseEntry(date: .now, state: .error(.noRecentReadings))
    GlucoseEntry(date: .now, state: .error(.loggedOut))
}
