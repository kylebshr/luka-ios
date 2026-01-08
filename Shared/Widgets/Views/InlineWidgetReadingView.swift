//
//  InlineWidgetReadingView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom
import Defaults

struct InlineWidgetReadingView: View {
    let entry: ReadingTimelineProvider.Entry
    let reading: GlucoseReading
    let delta: Int?

    @Environment(\.redactionReasons) private var redactionReasons
    @Default(.unit) private var unit
    @Default(.showDeltaInWidget) private var showDeltaInWidget

    var body: some View {
        HStack {
            if redactionReasons.isEmpty {
                reading.image
            }

            let timestamp = reading.timestamp(
                for: entry.date,
                style: .abbreviated,
                appendRelativeText: false,
                nowText: "Now"
            )

            if showDeltaInWidget, let delta {
                let deltaText = GlucoseReading.formattedDelta(delta, unit: unit)
                Text("\(reading.value.formatted(.glucose(unit))) \(deltaText) \(timestamp)")
            } else {
                Text("\(reading.value.formatted(.glucose(unit))) \(timestamp)")
            }
        }
        .containerBackground(.background, for: .widget)
    }
}
