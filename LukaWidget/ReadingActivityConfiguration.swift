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
                        context.timestamp
                        if !context.isStale {
                            Text(" • Last \(context.attributes.range.abbreviatedName)")
                        }
                    }
                    .font(.caption2.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    GraphPieceView(context: context)
                        .padding(.bottom, 10)
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
                CompactReadingText(context: context)
            } compactTrailing: {
                CompactReadingArrow(context: context)
            } minimal: {
                MinimalReadingView(context: context)
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

private struct CompactReadingText: View {
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

private struct CompactReadingArrow: View {
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

private struct MinimalReadingView: View {
    var context: ActivityViewContext<ReadingAttributes>

    var reading: GlucoseReading? {
        context.state.c
    }

    var body: some View {
        CompactReadingText(context: context)
            .fontWidth(.compressed)
            .minimumScaleFactor(0.8)
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
        case .small: .footnote.weight(.medium)
        @unknown default: .body
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                ReadingView(reading: context.state.c)
                    .font(largeFont)

                if family == .medium {
                    Spacer()
                }

                VStack(alignment: .trailing, spacing: 0) {
                    context.timestamp
                    if !context.isStale {
                        if family == .medium {
                            Text("Last \(context.attributes.range.abbreviatedName)")
                        }
                    }
                }
                .font(captionFont)
                .textCase(family == .small ? nil : .uppercase)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(family == .small ? .leading : .trailing)
                .contentTransition(.numericText())

                if !context.isStale {
                    if family == .small {
                        Spacer()
                        Text(context.attributes.range.abbreviatedName)
                            .font(captionFont.smallCaps())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding([.horizontal, .top], family == .medium ? nil : 10)

            GraphPieceView(context: context)
                .padding(.vertical, 10)
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

    var context: ActivityViewContext<ReadingAttributes>

    var body: some View {
        ZStack {
            LineChart(range: context.attributes.range, readings: context.state.h, lineWidth: 15)
                .blur(radius: 30)
                .opacity(0.8)
            LineChart(range: context.attributes.range, readings: context.state.h)
                .padding(.trailing)
        }
        .padding(.leading, -5)
        .frame(maxHeight: family == .medium ? 70 : nil)
    }
}

private extension ActivityViewContext<ReadingAttributes> {
    var timestamp: Text {
        let offlineText = Text("Offline").foregroundStyle(.red)

        if let current = state.c {
            if isStale {
                let lastReading = current.date.formatted(date: .omitted, time: .shortened)
                return Text("\(offlineText), as of \(lastReading)")
            } else {
                return Text("Live").foregroundStyle(.green)
            }
        } else {
            return offlineText
        }
    }
}

#Preview(as: .dynamicIsland(.expanded), using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
}

#Preview(as: .dynamicIsland(.compact), using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
}

#Preview(as: .dynamicIsland(.minimal), using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
}

#Preview(as: .content, using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
}
