//
//  ReadingActivityConfiguration.swift
//  LukaWidget
//
//  Created by Kyle Bashour on 10/16/25.
//

import WidgetKit
import ActivityKit
import Dexcom
import Foundation
import SwiftUI
import Defaults
import Charts

struct ReadingActivityConfiguration: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingAttributes.self) { context in
            VStack(alignment: .leading) {
                HStack(spacing: 5) {
                    MinimalReadingValue(reading: context.state.history.last)
                    MinimalReadingArrow(reading: context.state.history.last)
                }
                .padding(.horizontal)
                .padding(.top)

                GraphPieceView(history: context.state.history)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 5) {
                        MinimalReadingValue(reading: context.state.history.last)
                        MinimalReadingArrow(reading: context.state.history.last)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    GraphPieceView(history: context.state.history)
                }
            } compactLeading: {
                MinimalReadingValue(reading: context.state.history.last)
                    .redacted(reason: context.isStale ? .placeholder : [])
            } compactTrailing: {
                MinimalReadingArrow(reading: context.state.history.last)
            } minimal: {
                MinimalReadingArrow(reading: context.state.history.last)
            }
        }
    }
}

private struct MinimalReadingValue: View {
    @Default(.unit) private var unit
    var reading: GlucoseReading?

    var body: some View {
        WithRange { range in
            Text(reading?.value.formatted(.glucose(unit)) ?? "-")
                .fontWeight(.bold)
                .foregroundStyle(reading?.color(target: range) ?? .gray)
        }
    }
}

private struct MinimalReadingArrow: View {
    var reading: GlucoseReading?

    var body: some View {
        WithRange { range in
            (reading?.image ?? Image(systemName: "circle.fill"))
                .fontWeight(.bold)
                .foregroundStyle(reading?.color(target: range) ?? .gray)
        }
    }
}

private struct WithRange<Content: View>: View {
    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper

    var range: ClosedRange<Double> {
        targetLower...targetUpper
    }

    @ViewBuilder var content: (ClosedRange<Double>) -> Content

    var body: some View {
        content(range)
    }
}

private struct GraphPieceView: View {
    @Default(.graphUpperBound) private var upperBound

    var history: [GlucoseReading]

    var body: some View {
        WithRange { range in
            GraphView(
                range: .sixHours,
                readings: history,
                highlight: history.last,
                graphUpperBound: Int(upperBound),
                targetRange: Int(range.lowerBound)...Int(range.upperBound),
                roundBottomCorners: false,
                showMarkLabels: false
            )
        }
    }
}
