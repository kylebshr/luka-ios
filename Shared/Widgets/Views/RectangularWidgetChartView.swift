//
//  RectangularReadingView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom

struct RectangularWidgetChartView: View {
    let entry: ChartTimelineProvider.Entry
    let data: ChartGlucoseData

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        Button(intent: ReloadWidgetIntent()) {
            VStack(spacing: 5) {
                HStack {
                    HStack(spacing: 2) {
                        Text("\(data.current.value)")
                            .contentTransition(.numericText(value: Double(data.current.value)))
                            .invalidatableContent()

                        if redactionReasons.isEmpty {
                            data.current.image
                                .imageScale(.small)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }

                    Text(data.current.timestamp(for: entry.date, style: .abbreviated))
                        .contentTransition(.numericText(value: Double(entry.date.timeIntervalSinceNow)))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(data.chartRangeTitle)
                        .foregroundStyle(.secondary)
                }

                ChartView(
                    range: data.configuration.chartRange,
                    readings: data.history,
                    highlight: data.current,
                    chartUpperBound: data.chartUpperBound,
                    targetRange: data.targetLowerBound...data.targetUpperBound,
                    roundBottomCorners: watchOS
                )
            }
            .font(.system(size: watchOS ? 14 : 13, weight: .semibold))
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }
}
