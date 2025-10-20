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
            MainContentView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ZStack {
                        if let current = context.state.c,
                           !context.isStale {
                            Text(current.date.formatted(date: .omitted, time: .shortened))
                        } else {
                            Text("Offline")
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    GraphPieceView(history: context.state.h)
                }

                DynamicIslandExpandedRegion(.leading) {
                    ReadingText(context: context)
                        .font(.largeTitle)
                }
                .contentMargins([.leading, .top, .trailing], 20)

                DynamicIslandExpandedRegion(.trailing) {
                    ReadingArrow(context: context)
                        .font(.largeTitle)
                }
                .contentMargins([.leading, .top, .trailing], 20)

            } compactLeading: {
                MinimalReadingText(context: context)
            } compactTrailing: {
                MinimalReadingArrow(context: context)
            } minimal: {
                MinimalReadingArrow(context: context)
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

private struct ReadingText: View {
    @Default(.unit) private var unit
    var context: ActivityViewContext<ReadingAttributes>

    var reading: GlucoseReading? {
        context.state.c
    }

    var body: some View {
        ZStack {
            if let reading, !context.isStale {
                Text(reading.value.formatted(.glucose(unit)))
            } else {
                Text(50.formatted(.glucose(unit)))
                    .redacted(reason: .placeholder)
            }
        }
        .redacted(reason: context.isStale ? .placeholder : [])
        .fontDesign(.rounded)
    }
}

private struct ReadingArrow: View {
    var context: ActivityViewContext<ReadingAttributes>

    var reading: GlucoseReading? {
        context.state.c
    }

    var body: some View {
        if let reading {
            ZStack(alignment: .trailing) {
                ReadingText(context: context).hidden()
                reading.image.imageScale(.small)
                    .redacted(reason: context.isStale ? .placeholder : [])
            }
        }
    }
}

private struct MinimalReadingText: View {
    var context: ActivityViewContext<ReadingAttributes>

    var reading: GlucoseReading? {
        context.state.c
    }

    var body: some View {
        WithRange {
            ReadingText(context: context)
                .fontWeight(.bold)
                .foregroundStyle(reading?.color(target: $0) ?? .secondary)
        }
    }
}

private struct MinimalReadingArrow: View {
    var context: ActivityViewContext<ReadingAttributes>

    var reading: GlucoseReading? {
        context.state.c
    }

    var body: some View {
        WithRange {
            ReadingArrow(context: context)
                .fontWeight(.bold)
                .foregroundStyle(reading?.color(target: $0) ?? .secondary)
        }
    }
}

private struct MainContentView: View {
    var context: ActivityViewContext<ReadingAttributes>

    @Environment(\.activityFamily) var family

    var largeFont: Font {
        switch family {
        case .medium: .largeTitle
        case .small: .body.weight(.semibold)
        @unknown default: .largeTitle
        }
    }

    var captionFont: Font {
        switch family {
        case .medium: .caption.weight(.bold)
        case .small: .body.weight(.semibold)
        @unknown default: .body
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                ReadingView(reading: context.state.c)
                    .redacted(reason: context.isStale ? .placeholder : [])
                    .font(largeFont)
                    .fontDesign(.rounded)

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    if let current = context.state.c, !context.isStale {
                        Text(current.date.formatted(date: .omitted, time: .shortened))
                        if family == .medium {
                            Text("Last 6hr")
                                .font(captionFont.smallCaps())
                        }
                    } else {
                        Text("Offline")
                    }
                }
                .font(captionFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .contentTransition(.numericText())
            }
            .padding([.horizontal, .top], family == .medium ? nil : 5)

            GraphPieceView(history: context.state.h)
                .padding(.vertical, family == .medium ? 10 : 4)
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
    @Environment(\.activityFamily) private var family

    var history: [LiveActivityState.Reading]

    var body: some View {
        LineChart(range: .sixHours, readings: history)
            .padding(.trailing)
            .padding(.leading, -5)
            .frame(maxHeight: family == .medium ? 70 : nil)
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
