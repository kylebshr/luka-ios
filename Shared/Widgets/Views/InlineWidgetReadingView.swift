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

    @Environment(\.redactionReasons) private var redactionReasons
    @Default(.unit) private var unit

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

            Text("\(reading.value.formatted(.glucose(unit))) \(timestamp)")
        }
        .containerBackground(.background, for: .widget)
    }
}
