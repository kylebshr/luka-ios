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
            VStack(spacing: 0) {
                HStack {
                    ReadingText(reading: context.state.c)
                        .redacted(reason: context.isStale ? .placeholder : [])
                        .font(.largeTitle)
                        .frame(maxHeight: .infinity)
                        .redacted(reason: context.isStale ? .placeholder : [])
                    Spacer()
                    Text("Last three hours")
                        .font(.body.smallCaps())
                        .textScale(.secondary)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ReadingArrow(reading: context.state.c)
                        .redacted(reason: context.isStale ? .placeholder : [])
                        .font(.largeTitle)
                        
                        .redacted(reason: context.isStale ? .placeholder : [])
                }
                .padding([.horizontal])

                GraphPieceView(history: context.state.h)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("Last three hours")
                        .font(.body.smallCaps())
                        .textScale(.secondary)
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    GraphPieceView(history: context.state.h)
                }

                DynamicIslandExpandedRegion(.leading) {
                    ReadingText(reading: context.state.c)
                        .font(.largeTitle)
                        .redacted(reason: context.isStale ? .placeholder : [])
                }
                .contentMargins([.leading, .top, .trailing], 20)

                DynamicIslandExpandedRegion(.trailing) {
                    ReadingArrow(reading: context.state.c)
                        .font(.largeTitle)
                        .redacted(reason: context.isStale ? .placeholder : [])
                }
                .contentMargins([.leading, .top, .trailing], 20)

            } compactLeading: {
                MinimalReadingText(reading: context.state.c)
                    .redacted(reason: context.isStale ? .placeholder : [])
            } compactTrailing: {
                MinimalReadingArrow(reading: context.state.c)
                    .redacted(reason: context.isStale ? .placeholder : [])
            } minimal: {
                MinimalReadingArrow(reading: context.state.c)
                    .redacted(reason: context.isStale ? .placeholder : [])
            }
        }
    }
}

private struct ReadingText: View {
    @Default(.unit) private var unit
    var reading: GlucoseReading?

    var body: some View {
        Text(reading?.value.formatted(.glucose(unit)) ?? "-")
            .fontDesign(.rounded)
    }
}

private struct ReadingArrow: View {
    var reading: GlucoseReading?

    var body: some View {
        ZStack(alignment: .trailing) {
            ReadingText(reading: reading).hidden()
            reading?.image ?? Image(systemName: "circle.fill")
        }
    }
}

private struct MinimalReadingText: View {
    var reading: GlucoseReading?

    var body: some View {
        WithRange {
            ReadingText(reading: reading)
                .fontWeight(.bold)
                .foregroundStyle(reading?.color(target: $0) ?? .secondary)
        }
    }
}

private struct MinimalReadingArrow: View {
    var reading: GlucoseReading?

    var body: some View {
        WithRange {
            ReadingArrow(reading: reading)
                .fontWeight(.bold)
                .foregroundStyle(reading?.color(target: $0) ?? .secondary)
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

    var history: [LiveActivityState.Reading]

    var body: some View {
        LineChart(range: .threeHours, readings: history)
            .padding(.trailing)
            .padding(.leading, -5)
    }
}

#Preview(as: .dynamicIsland(.expanded), using: ReadingAttributes()) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
}

#Preview(as: .dynamicIsland(.compact), using: ReadingAttributes()) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
}

#Preview(as: .dynamicIsland(.minimal), using: ReadingAttributes()) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
}

#Preview(as: .content, using: ReadingAttributes()) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
}
