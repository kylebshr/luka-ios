//
//  RectangularReadingView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom

struct RectangularWidgetReadingView: View {
    let entry: Provider.Entry
    let reading: GlucoseReading

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 2) {
                    Text("\(reading.value)")
                        .contentTransition(.numericText(value: Double(reading.value)))
                    
                    if redactionReasons.isEmpty {
                        reading.image
                            .contentTransition(.symbolEffect(.replace))
                    }
                }

                Text(reading.timestamp(for: entry.date))
                    .contentTransition(.numericText(value: Double(entry.date.timeIntervalSinceNow)))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            #if !os(watchOS)
            Button(intent: ReloadWidgetIntent()) {
                Image(systemName: "arrow.circlepath")
            }
            .unredacted()
            #endif
        }
        .fontWeight(.semibold)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .containerBackground(reading.color.gradient, for: .widget)
    }
}
