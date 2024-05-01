//
//  SystemWidgetReadingView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import WidgetKit
import Dexcom

struct SystemWidgetReadingView: View {
    let entry: Provider.Entry
    let reading: GlucoseReading
    let history: [GlucoseReading]

    @Environment(\.showsWidgetContainerBackground) var showsWidgetContainerBackground
    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetContentMargins) private var widgetContentMargins

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(reading.value.formatted())
                        .contentTransition(.numericText(value: Double(reading.value)))
                        .invalidatableContent()

                    if redactionReasons.isEmpty {
                        reading.image
                            .imageScale(.small)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .font(.system(.headline, design: .rounded, weight: .semibold))

                Spacer()

                Text(entry.chartRangeTitle)
                    .foregroundStyle(.secondary)
                    .font(.caption2)
            }

            ChartView(
                range: entry.configuration.chartRange,
                readings: history,
                highlight: reading,
                chartUpperBound: entry.chartUpperBound,
                targetRange: entry.targetLowerBound...entry.targetUpperBound,
                roundBottomCorners: false
            )
            .padding(.leading, -widgetContentMargins.leading)
            .padding(.trailing, -widgetContentMargins.trailing)

            Spacer(minLength: 12)

            Button(intent: ReloadWidgetIntent()) {
                HStack {
                    Text(reading.timestamp(for: entry.date))
                        .contentTransition(.numericText(value: reading.date.timeIntervalSinceNow))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "arrow.circlepath")
                        .foregroundStyle(.secondary)
                        .unredacted()
                }
                .font(.caption2)
            }
            .buttonStyle(.plain)
            .tint(.primary)
        }
        .fontWeight(.semibold)
        .standByMargins()
        .containerBackground(.background, for: .widget)
    }
}
