//
//  CornerWidgetReadingView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/18/26.
//

import Dexcom
import SwiftUI
import WidgetKit
import Defaults

struct CornerWidgetView: View {
    let entry: ReadingTimelineProvider.Entry
    let reading: GlucoseReading

    @Environment(\.redactionReasons) private var redactionReasons

    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper
    @Default(.unit) private var unit

    var body: some View {
        Group {
            if entry.widgetURL == nil {
                Button(intent: ReloadWidgetIntent()) {
                    content
                }
            } else {
                content
            }
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }

    private var text: String {
        let value = redactionReasons.isEmpty ? reading.value.formatted(.glucose(unit)) : "80"
        let timestamp = reading.timestamp(
            for: entry.date,
            style: .abbreviated,
            appendRelativeText: false
        ).localizedLowercase

        if redactionReasons.isEmpty, let arrow = reading.trendArrow {
            return "\(value) \(arrow) \(timestamp)"
        } else {
            return "\(value) \(timestamp)"
        }
    }

    private var content: some View {
        Text(text)
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .invalidatableContent()
            .foregroundStyle(reading.color(target: targetLower...targetUpper))
    }
}

private extension GlucoseReading {
    var trendArrow: String? {
        switch trend {
        case .none, .notComputable, .rateOutOfRange: nil
        case .doubleUp: "⇈"
        case .singleUp: "↑"
        case .fortyFiveUp: "↗"
        case .flat: "→"
        case .fortyFiveDown: "↘"
        case .singleDown: "↓"
        case .doubleDown: "⇊"
        }
    }
}
