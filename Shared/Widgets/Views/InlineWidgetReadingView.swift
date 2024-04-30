//
//  InlineWidgetReadingView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom

struct InlineWidgetReadingView: View {
    let entry: Provider.Entry
    let reading: GlucoseReading

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        HStack {
            if redactionReasons.isEmpty {
                reading.image
            }

            let timestamp = reading.timestamp(
                for: entry.date,
                style: .abbreviated,
                nowText: "1m"
            )

            Text("\(reading.value) \(timestamp)")
                .font(.body.lowercaseSmallCaps())
        }
        .containerBackground(.background, for: .widget)
    }
}
