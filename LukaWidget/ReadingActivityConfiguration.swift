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
            let sessionExpired = context.state.se == true
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    if sessionExpired {
                        HStack {
                            Text("Session expired")
                            Spacer()
                            Button(
                                "Renew",
                                systemImage: "arrow.clockwise",
                                intent: StartLiveActivityIntent(source: "LiveActivity")
                            )
                        }
                        .fontWeight(.medium)
                    } else {
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
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if !sessionExpired {
                        GraphPieceView(context: context)
                            .padding(.bottom, 10)
                    }
                }

                DynamicIslandExpandedRegion(.leading) {
                    if !sessionExpired {
                        ReadingText(context: context)
                            .font(.largeTitle)
                            .fontDesign(.rounded)
                    }
                }
                .contentMargins([.leading, .top, .trailing], 20)

                DynamicIslandExpandedRegion(.trailing) {
                    if !sessionExpired {
                        ReadingArrow(context: context)
                            .font(.largeTitle)
                    }
                }
                .contentMargins([.leading, .top, .trailing], 20)

            } compactLeading: {
                if sessionExpired {
                    Image(systemName: "person.slash")
                        .fontWeight(.bold)
                } else {
                    CompactReadingText(context: context)
                }
            } compactTrailing: {
                if sessionExpired {
                    Image(systemName: "arrow.clockwise")
                        .fontWeight(.bold)
                } else {
                    CompactReadingArrow(context: context)
                }
            } minimal: {
                if sessionExpired {
                    Image(systemName: "user.slash")
                        .fontWeight(.bold)
                } else {
                    ViewThatFits {
                        HStack(spacing: 0) {
                            MinimalReadingView(context: context)
                            CompactReadingArrow(context: context)
                                .imageScale(.small)
                                .font(.caption2)
                        }

                        MinimalReadingView(context: context)
                    }
                }
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
        WithRange {
            ReadingText(context: context)
                .fontWeight(.semibold)
                .fontWidth(.compressed)
                .foregroundStyle((reading?.color(target: $0) ?? .secondary).gradient)
                .redacted(reason: context.isStale ? .placeholder : [])
        }
    }
}

private struct MainContentView: View {
    var context: ActivityViewContext<ReadingAttributes>

    @Environment(\.activityFamily) private var family
    @Default(.showChartLiveActivity) private var showChartLiveActivity

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

                Spacer(minLength: 0)

                context.timestamp
                    .lineLimit(2)
                    .font(.caption2.weight(.medium))
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.5)
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

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        context.timestamp
                        if showChartLiveActivity {
                            if context.state.c != nil, !context.isStale {
                                Text("Last \(context.attributes.range.abbreviatedName)")
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
        HStack {
            Text("Session expired")
            Spacer()
            Button(
                "Renew",
                systemImage: "arrow.clockwise",
                intent: StartLiveActivityIntent(source: "LiveActivity")
            )
        }
        .fontWeight(.medium)
        .padding()
    }

    func smallExpiredView() -> some View {
        Button(
            "Renew Session",
            intent: StartLiveActivityIntent(source: "LiveActivity")
        )
        .fontWeight(.medium)
        .multilineTextAlignment(.center)
        .padding(10)
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
                .opacity(0.85)
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
                return Text("\(offlineText) at \(lastReading)")
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
    LiveActivityState(h: [], se: true)
}

#Preview(as: .dynamicIsland(.compact), using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(h: [], se: true)
}

#Preview(as: .dynamicIsland(.minimal), using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(h: [], se: true)
}

#Preview(as: .content, using: ReadingAttributes(range: .threeHours)) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(h: [], se: true)
}
