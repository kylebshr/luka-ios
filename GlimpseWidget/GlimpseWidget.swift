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
    GlucoseEntry(
        configuration: .init(),
        date: .now,
        state: .reading(.placeholder, history: .placeholder)
    )
    GlucoseEntry(
        configuration: .init(),
        date: .now,
        state: .reading(
            .init(
                value: 50,
                trend: .fortyFiveDown,
                date: .now - 320
            ),
            history: .placeholder
        )
    )
    GlucoseEntry(
        configuration: .init(),
        date: .now,
        state: .reading(
            .init(
                value: 50,
                trend: .singleDown,
                date: .now - 320
            ),
            history: .placeholder
        )
    )
    GlucoseEntry(
        configuration: .init(),
        date: .now,
        state: .reading(
            .init(
                value: 50,
                trend: .doubleDown,
                date: .now - 320
            ),
            history: .placeholder
        )
    )
    GlucoseEntry(
        configuration: .init(),
        date: .now,
        state: .reading(
            .init(
                value: 50,
                trend: .notComputable,
                date: .now - 320
            ),
            history: .placeholder
        )
    )
    GlucoseEntry(
        configuration: .init(),
        date: .now,
        state: .reading(
            .init(
                value: 183,
                trend: .doubleUp,
                date: .now - 2000
            ),
            history: .placeholder
        )
    )
    GlucoseEntry(configuration: .init(), date: .now, state: .error(.failedToLoad))
    GlucoseEntry(configuration: .init(), date: .now, state: .error(.noRecentReadings))
    GlucoseEntry(configuration: .init(), date: .now, state: .error(.loggedOut))
}
