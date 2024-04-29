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
    let history: [GlucoseReading]

    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 2) {
                    Text("\(reading.value)")
                        .contentTransition(.numericText(value: Double(reading.value)))
                        .invalidatableContent()

                    if redactionReasons.isEmpty {
                        reading.image
                            .contentTransition(.symbolEffect(.replace))
                    }
                }

                Text(reading.timestamp(for: entry.date, style: .abbreviated))
                    .contentTransition(.numericText(value: Double(entry.date.timeIntervalSinceNow)))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(entry.chartRangeTitle)
                    .unredacted()
                    .foregroundStyle(.secondary)
            }

            ChartView(
                range: entry.configuration.chartRange,
                readings: history,
                chartUpperBound: entry.chartUpperBound,
                targetRange: entry.targetLowerBound...entry.targetUpperBound,
                vibrantRenderingMode: widgetRenderingMode == .vibrant
            )
        }
        .font(.footnote)
        .fontWeight(.semibold)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
