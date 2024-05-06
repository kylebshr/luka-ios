//
//  SystemWidgetReadingView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import WidgetKit
import Dexcom

struct SystemWidgetGraphView: View {
    let entry: GraphTimelineProvider.Entry
    let data: GlucoseGraphEntryData

    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetContentMargins) private var widgetContentMargins

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(data.current.value.formatted())
                        .contentTransition(.numericText(value: Double(data.current.value)))
                        .invalidatableContent()

                    if redactionReasons.isEmpty {
                        data.current.image
                            .imageScale(.small)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)

                Spacer()

                Text(data.graphRangeTitle)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            GraphView(
                range: data.configuration.graphRange,
                readings: data.history,
                highlight: data.current,
                graphUpperBound: data.graphUpperBound,
                targetRange: data.targetLowerBound...data.targetUpperBound,
                roundBottomCorners: false
            )
            .padding(.leading, -widgetContentMargins.leading)
            .padding(.trailing, -widgetContentMargins.trailing)

            Spacer(minLength: 12)

            Button(intent: ReloadWidgetIntent()) {
                WidgetButtonContent(
                    text: data.current.timestamp(for: entry.date),
                    image: "arrow.circlepath"
                )
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .tint(.primary)
        }
        .fontWeight(.medium)
        .standByMargins()
        .containerBackground(.background, for: .widget)
    }
}
