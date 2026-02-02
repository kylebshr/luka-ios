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
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 0) {
                        if context.isOffline {
                            context.timestamp(relative: true).multilineTextAlignment(.center)
                        } else {
                            Text("\(context.timestamp(relative: true)) • Last \(context.attributes.range.abbreviatedName)", comment: "Live Activity label showing graph range")
                        }
                    }
                    .multilineTextAlignment(.center)
                    .font(.caption2.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 200)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if !context.isOffline {
                        GraphPieceView(context: context)
                            .padding(.bottom, 10)
                    }
                }

                DynamicIslandExpandedRegion(.leading) {
                    ReadingText(context: context)
                        .font(.largeTitle)
                        .fontDesign(.rounded)
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
                HStack(spacing: 0) {
                    MinimalReadingView(context: context)
                    CompactReadingArrow(context: context)
                        .imageScale(.small)
                        .font(.caption2)
                }
                .minimumScaleFactor(0.95)
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
                .redacted(reason: context.isOffline ? .placeholder : [])
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
                .redacted(reason: context.isOffline ? .placeholder : [])
        }
    }
}

private struct MinimalReadingView: View {
    var context: ActivityViewContext<ReadingAttributes>

    var reading: GlucoseReading? {
        context.state.c
    }

    var body: some View {
        WithRange {
            ReadingText(context: context)
                .fontWeight(.bold)
                .fontWidth(.compressed)
                .foregroundStyle((reading?.color(target: $0) ?? .secondary).gradient)
                .redacted(reason: context.isOffline ? .placeholder : [])
        }
    }
}

private struct MainContentView: View {
    var context: ActivityViewContext<ReadingAttributes>

    @Environment(\.activityFamily) private var family
    @Default(.showChartLiveActivity) private var _showChartLiveActivity

    var showChartLiveActivity: Bool {
        _showChartLiveActivity && !context.isOffline
    }

    var body: some View {
        switch family {
        case .small: smallContentView()
        case .medium: mediumContentView()
        @unknown default: mediumContentView()
        }
    }

    @ViewBuilder func smallContentView() -> some View {
        if context.state.se == true {
            smallExpiredView()
        } else {
            HStack(spacing: 0) {
                ReadingView(reading: context.state.c)
                    .font(.title.weight(.regular))
                    .layoutPriority(100)

                Spacer(minLength: 0)

                context.timestamp(relative: false)
                    .lineLimit(2)
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.5)
                    .layoutPriority(10)
            }
            .padding(10)
        }
    }

    @ViewBuilder func mediumContentView() -> some View {
        if context.state.se == true {
            mediumExpiredView()
        } else {
            VStack(spacing: 0) {
                HStack {
                    ReadingView(reading: context.state.c)
                        .font(.largeTitle)
                        .fontDesign(.rounded)
                        .opacity(context.isOffline ? 0.5 : 1)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        context.timestamp(relative: true)
                        if showChartLiveActivity {
                            if context.state.c != nil, !context.isOffline {
                                Text("Last \(context.attributes.range.abbreviatedName)", comment: "Live Activity label showing graph range")
                            }
                        }
                    }
                    .font(.caption2.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .contentTransition(.numericText())
                }
                .padding([.horizontal, .top])
                .padding(showChartLiveActivity ? [] : .bottom)

                if showChartLiveActivity {
                    GraphPieceView(context: context)
                        .padding(.top, 10)
                        .padding(.bottom)
                }
            }
        }
    }

    func mediumExpiredView() -> some View {
        MediumExpiredView()
    }

    func smallExpiredView() -> some View {
        VStack(alignment: .leading) {
            Text("Live Activity ended")
                .font(.footnote)

            HStack {
                Button(intent: EndLiveActivityIntent()) {
                    Image(systemName: "xmark")
                }
                .tint(.primary)
                .buttonBorderShape(.circle)

                Button(intent: StartLiveActivityIntent(source: "LiveActivity")) {
                    Label("Restart", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity)
                }
                .tint(.green)
            }
            .font(.caption)
        }
        .fontWeight(.medium)
        .multilineTextAlignment(.center)
        .padding(10)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MediumExpiredView: View {
    var body: some View {
        HStack {
            Text("Live Activity ended")

            Spacer()

            Button(intent: EndLiveActivityIntent()) {
                Image(systemName: "xmark")
                    .font(.system(size: 24))
                    .padding(2)
            }
            .tint(.primary)

            Button(intent: StartLiveActivityIntent(source: "LiveActivity")) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 24))
                    .padding(2)
            }
            .tint(.green)
        }
        .fixedSize(horizontal: false, vertical: true)
        .buttonBorderShape(.circle)
        .fontWeight(.medium)
        .padding()
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
            LineChart(
                range: context.attributes.range,
                style: .line,
                readings: context.state.h,
                lineWidth: 15
            )
            .saturation(2)
            .blur(radius: 30)
            .opacity(0.85)

            LineChart(
                range: context.attributes.range,
                style: Defaults[.liveActivityGraphStyle],
                readings: context.state.h
            )
            .padding(.trailing)
        }
        .padding(.leading, -5)
        .frame(maxHeight: family == .medium ? 70 : nil)
    }
}

private extension ActivityViewContext<ReadingAttributes> {
    var isOffline: Bool {
        if let reading = state.c {
            return isStale || reading.isExpired(at: .now, expiration: .init(value: 10, unit: .minutes))
        } else {
            return isStale
        }
    }

    private var timestampColor: Color {
        if let reading = state.c {
            if reading.isExpired(at: .now, expiration: .init(value: 10, unit: .minutes)) {
                return .red
            } else if reading.isExpired(at: .now, expiration: .init(value: 5, unit: .minutes)) {
                return .orange
            } else {
                return .green
            }
        } else {
            return .red
        }
    }

    func timestamp(relative: Bool = true) -> Text {
        if let current = state.c {
            var text = Text(
                timerInterval: current.date...Date.distantFuture,
                countsDown: false
            )

            if relative {
                text = text + Text(" Ago")
            }

            return text.foregroundStyle(timestampColor)
        } else {
            return Text("Offline", comment: "Status indicator when Live Activity is not receiving updates")
                .foregroundStyle(.red)
        }
    }
}

#Preview(as: .dynamicIsland(.expanded), using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-10 * 61)), h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-5 * 61)), h: .placeholder)
    LiveActivityState(c: nil, h: [], se: true)
}

#Preview(as: .dynamicIsland(.compact), using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-10 * 61)), h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-5 * 61)), h: .placeholder)
    LiveActivityState(c: nil, h: [], se: true)
}

#Preview(as: .dynamicIsland(.minimal), using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-10 * 61)), h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-5 * 61)), h: .placeholder)
    LiveActivityState(c: nil, h: [], se: true)
}

#Preview(as: .content, using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-10 * 61)), h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-5 * 61)), h: .placeholder)
    LiveActivityState(c: nil, h: [], se: true)
}
