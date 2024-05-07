//
//  RectangularReadingView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom

struct WidgetGraphView: View {
    let entry: GraphTimelineProvider.Entry
    let data: GlucoseGraphEntryData

    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetContentMargins) private var margins

    private var isInStandby: Bool {
        margins.leading > 0 && margins.leading < 5
    }

    var body: some View {
            GeometryReader { geometry in
                VStack(spacing: geometry.size.height > 100 ? nil : 5) {
                    Button(intent: ReloadWidgetIntent()) {
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

                            Group {
                                HStack(spacing: 2) {
                                    ViewThatFits {
                                        Text(data.current.timestamp(for: entry.date))
                                        Text(data.current.timestamp(for: entry.date, style: .abbreviated, appendRelativeText: true))
                                        Text(data.current.timestamp(for: entry.date, style: .abbreviated, appendRelativeText: false))
                                    }
                                    .contentTransition(.numericText())

                                    Spacer(minLength: 5)

                                    #if os(iOS)
                                    if entry.shouldRefresh {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .imageScale(.small)
                                            .unredacted()
                                    } else {
                                        Text(data.graphRangeTitle)
                                    }
                                    #else
                                    Text(data.graphRangeTitle)
                                    #endif
                                }
                            }
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                        }
                    }

                    GraphView(
                        range: data.configuration.graphRange,
                        readings: data.history,
                        highlight: data.current,
                        graphUpperBound: data.graphUpperBound,
                        targetRange: data.targetLowerBound...data.targetUpperBound,
                        roundBottomCorners: !isInStandby,
                        showMarkLabels: false
                    )
                }
                .font(.system(size: watchOS ? 15 : 13, weight: .semibold))
            }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }
}
