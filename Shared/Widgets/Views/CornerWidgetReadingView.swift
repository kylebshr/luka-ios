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

    private var content: some View {
        Text(redactionReasons.isEmpty ? reading.value.formatted(.glucose(unit)) : "80")
            .font(.title3)
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .invalidatableContent()
            .foregroundStyle(reading.color(target: targetLower...targetUpper))
            .widgetLabel {
                label
            }
    }

    private var label: Text {
        let value = redactionReasons.isEmpty ? reading.value.formatted(.glucose(unit)) : "80"
        let timestamp = reading.timestamp(
            for: entry.date,
            style: .abbreviated,
            appendRelativeText: false
        ).localizedLowercase

        if redactionReasons.isEmpty, let image = reading.image {
            return Text("\(value) \(image) \(timestamp)")
        } else {
            return Text("\(value) \(timestamp)")
        }
    }
}
