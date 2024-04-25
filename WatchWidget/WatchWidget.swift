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
            if entry.isExpired {
                GlimpseWidgetEntryView(entry: entry)
                    .redacted(reason: .placeholder)
            } else {
                GlimpseWidgetEntryView(entry: entry)
            }
        }
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular) {
    WatchWidget()
} timeline: {
    GlucoseEntry(date: .now, state: .reading(.placeholder))
    GlucoseEntry(date: .now, state: .reading(.init(value: 94, trend: .fortyFiveUp, date: .now - 60)))
    GlucoseEntry(date: .now, state: .reading(.init(value: 102, trend: .doubleDown, date: .now - 400)))
    GlucoseEntry(date: .now.addingTimeInterval(20 * 60), state: .reading(.init(value: 183, trend: .doubleUp, date: .now - 900)))
    GlucoseEntry(date: .now, state: .reading(nil))
    GlucoseEntry(date: .now, state: .loggedOut)
}
