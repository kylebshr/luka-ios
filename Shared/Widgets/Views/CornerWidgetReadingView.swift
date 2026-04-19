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
            .fontWeight(.bold)
            .invalidatableContent()
            .foregroundStyle(tintColor)
            .widgetCurvesContent()
            .widgetLabel {
                let value = Double(reading.value)
                let lower = min(value, targetLower)
                let upper = max(value, targetUpper)
                Gauge(value: value, in: lower...upper) {
                    EmptyView()
                } currentValueLabel: {
                    Text(reading.value.formatted(.glucose(unit)))
                } minimumValueLabel: {
                    Text(Int(lower).formatted(.glucose(unit)))
                } maximumValueLabel: {
                    Text(Int(upper).formatted(.glucose(unit)))
                }
                .tint(tintColor)
            }
    }

    private var tintColor: Color {
        switch Double(reading.value) {
        case ..<targetLower: .red
        case ...targetUpper: .green
        default: .yellow
        }
    }
}

#if os(watchOS)
#Preview(as: .accessoryCorner) {
    ReadingWidget()
} timeline: {
    GlucoseEntry<GlucoseReading>(
        date: .now,
        widgetURL: nil,
        state: .reading(.init(value: 55, trend: .fortyFiveDown, date: .now))
    )
}
#endif
