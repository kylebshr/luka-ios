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
            context.state.history.last?.image
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MinimalReadingValue(reading: context.state.history.last)
                        .padding()
                }

                DynamicIslandExpandedRegion(.trailing) {
                    MinimalReadingArrow(reading: context.state.history.last)
                        .padding()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Chart {
                        ForEach(context.state.history) { reading in
                            LineMark(
                                x: .value("Date", reading.date),
                                y: .value("Value", reading.value)
                            )
                        }
                    }
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
    var reading: GlucoseReading?

    var body: some View {
        WithRange { range in
            Text(reading?.value.formatted() ?? "-")
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
