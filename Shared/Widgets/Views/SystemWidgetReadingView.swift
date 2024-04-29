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
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(reading.value)")
                    .contentTransition(.numericText(value: Double(reading.value)))
                    .invalidatableContent()

                if redactionReasons.isEmpty {
                    reading.image
                        .imageScale(.small)
                        .contentTransition(.symbolEffect(.replace))
                }

                Spacer()

                Text("8H")
                    .foregroundStyle(.secondary)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .unredacted()
            }
            .font(.title3)
            .fontWeight(.semibold)

            ChartView(
                range: Date.now.addingTimeInterval(-60 * 60 * 3)...Date.now,
                readings: history,
                maximumY: 300,
                targetRange: 70...180
            )
            .padding(.leading, -widgetContentMargins.leading)
            .padding(.trailing, -widgetContentMargins.trailing)

            Spacer(minLength: 10)

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
                .fontWeight(.medium)
            }
            .buttonStyle(.plain)
            .tint(.primary)
        }
        .fontDesign(.rounded)
        .standByMargins()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
