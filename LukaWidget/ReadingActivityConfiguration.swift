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
    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingAttributes.self) { context in
            MainContentView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 0) {
                        Text(context.timestamp)
                        if !context.isStale {
                            Text(" • Last 6hr")
                        }
                    }
                    .font(.caption2.bold())
                    .textCase(.uppercase)
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
            .keylineTint(context.state.c?.color(target: targetLower...targetUpper))
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
            if let reading {
                Text(reading.value.formatted(.glucose(unit)))
            } else {
                Text(50.formatted(.glucose(unit)))
                    .redacted(reason: .placeholder)
            }
        }
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
                .foregroundStyle((reading?.color(target: $0) ?? .secondary).gradient)
                .redacted(reason: context.isStale ? .placeholder : [])
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
            reading?.image
                .fontWeight(.bold)
                .foregroundStyle((reading?.color(target: $0) ?? .secondary).gradient)
                .redacted(reason: context.isStale ? .placeholder : [])
        }
    }
}

private struct MainContentView: View {
    var context: ActivityViewContext<ReadingAttributes>

    @Environment(\.activityFamily) var family

    var largeFont: Font {
        switch family {
        case .medium: .largeTitle
        case .small: .footnote.weight(.bold)
        @unknown default: .largeTitle
        }
    }

    var captionFont: Font {
        switch family {
        case .medium: .caption2.bold()
        case .small: .footnote.weight(.medium).smallCaps()
        @unknown default: .body
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                ReadingView(reading: context.state.c)
                    .font(largeFont)
                    .fontDesign(.rounded)

                if family == .medium {
                    Spacer()
                }

                VStack(alignment: .trailing, spacing: 0) {
                    Text(context.timestamp)
                    if !context.isStale {
                        if family == .medium {
                            Text("Last 6hr")
                        }
                    }
                }
                .font(captionFont)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(family == .small ? .leading : .trailing)
                .contentTransition(.numericText())

                if !context.isStale {
                    if family == .small {
                        Spacer()
                        Text("6H")
                            .font(captionFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding([.horizontal, .top], family == .medium ? nil : 10)

            GraphPieceView(history: context.state.h)
                .padding(.vertical, family == .medium ? 10 : 2)
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
        ZStack {
            LineChart(range: .sixHours, readings: history, lineWidth: 15)
                .blur(radius: 30)
                .opacity(0.8)
            LineChart(range: .sixHours, readings: history)
                .padding(.trailing)
        }
        .padding(.leading, -5)
        .frame(maxHeight: family == .medium ? 70 : nil)
    }
}

private extension ActivityViewContext<ReadingAttributes> {
    var timestamp: String {
        if let current = state.c {
            if isStale {
                current.date.formatted(date: .omitted, time: .shortened)
            } else {
                "Live"
            }
        } else {
            "Offline"
        }
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

struct Foo: PreviewProvider {
    static var previews: some View {
        ReadingAttributes().previewContext(
            LiveActivityState(c: .placeholder, h: .placeholder),
            isStale: true,
            viewKind: .dynamicIsland(.compact)
        )
    }
}
