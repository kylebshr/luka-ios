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

#if os(iOS)
private var previewAccounts: [ReadingTimelineProvider.Entry.Account] {
    [
        .init(name: "Alex", state: .reading(.init(value: 112, trend: .flat, date: .now.addingTimeInterval(-90)))),
        .init(name: "Sam", state: .reading(.init(value: 243, trend: .fortyFiveUp, date: .now.addingTimeInterval(-240)))),
        .init(name: "Jordan", state: .reading(.init(value: 64, trend: .singleDown, date: .now.addingTimeInterval(-60 * 11)))),
        .init(name: "Riley", state: .error(.failedToLoad)),
    ]
}

private func previewEntry(accounts count: Int, date: Date = .now) -> ReadingTimelineProvider.Entry {
    GlucoseEntry(date: date, widgetURL: nil, accounts: Array(previewAccounts.prefix(count)))
}

#Preview("One of several accounts", as: .systemSmall) {
    ReadingWidget()
} timeline: {
    previewEntry(accounts: 1)
}

#Preview("Two accounts", as: .systemSmall) {
    ReadingWidget()
} timeline: {
    previewEntry(accounts: 2)
}

#Preview("Two accounts", as: .systemMedium) {
    ReadingWidget()
} timeline: {
    previewEntry(accounts: 2)
    previewEntry(accounts: 2, date: .now.addingTimeInterval(60 * 24))
}

#Preview("Four accounts", as: .systemLarge) {
    ReadingWidget()
} timeline: {
    previewEntry(accounts: 4)
    previewEntry(accounts: 3)
    previewEntry(accounts: 2)
}

#Preview("Two accounts", as: .accessoryRectangular) {
    ReadingWidget()
} timeline: {
    previewEntry(accounts: 2)
    GlucoseEntry(date: .now, widgetURL: nil, accounts: Array(previewAccounts.suffix(2)))
}
#endif
