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
        Button(intent: ReloadWidgetIntent()) {
            VStack(spacing: 5) {
                HStack {
                    HStack(spacing: 2) {
                        Text("\(reading.value)")
                            .contentTransition(.numericText(value: Double(reading.value)))
                            .invalidatableContent()

                        if redactionReasons.isEmpty {
                            reading.image
                                .imageScale(.small)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }

                    Text(reading.timestamp(for: entry.date, style: .abbreviated))
                        .contentTransition(.numericText(value: Double(entry.date.timeIntervalSinceNow)))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(entry.chartRangeTitle)
                        .foregroundStyle(.secondary)
                }

                ChartView(
                    range: entry.configuration.chartRange,
                    readings: history,
                    highlight: reading,
                    chartUpperBound: entry.chartUpperBound,
                    targetRange: entry.targetLowerBound...entry.targetUpperBound,
                    vibrantRenderingMode: widgetRenderingMode == .vibrant,
                    roundBottomCorners: true
                )
            }
            .font(.system(size: watchOS ? 14 : 13, weight: .semibold))
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }
}
