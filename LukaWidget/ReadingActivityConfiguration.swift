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
    @Default(.liveActivityTapApp) private var tapApp

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingAttributes.self) { context in
            MainContentView(context: context)
                .widgetURL(tapApp.url)
        } dynamicIsland: { context in
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 0) {
                        if context.isOffline {
                            context.timestamp
                        } else {
                            Text("\(context.timestamp) • Last \(context.attributes.range.abbreviatedName)", comment: "Live Activity label showing graph range")
                        }
                    }
                    .multilineTextAlignment(.center)
                    .font(.caption2.bold())
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 150)
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
                        .opacity(context.isOffline ? 0.5 : 1)
                        .fixedSize(horizontal: true, vertical: true)
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
                    .fixedSize()
            }
            .keylineTint(context.state.c?.color(target: targetLower...targetUpper))
            .widgetURL(tapApp.url)
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
        .lowercaseSmallCaps()
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

/// The compact/minimal Live Activity tint, nudged into HDR headroom on iOS 26
/// so the reading glows in the Dynamic Island. Falls back to the SDR gradient
/// on older OSes and non-HDR displays, and to `.secondary` when there's no
/// reading.
private func liveActivityReadingTint(_ reading: GlucoseReading?, target: ClosedRange<Double>) -> AnyShapeStyle {
    guard let reading else {
        return AnyShapeStyle(Color.secondary.gradient)
    }
    let color = reading.color(target: target)
    if #available(iOS 26, *) {
        return AnyShapeStyle(color.exposureAdjust(0.25).gradient)
    } else {
        return AnyShapeStyle(color.gradient)
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
                .foregroundStyle(liveActivityReadingTint(reading, target: $0))
                .opacity(context.isOffline ? 0.5 : 1)
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
            ZStack {
                if context.isOffline {
                    Image(systemName: "wifi.slash")
                        .symbolRenderingMode(.hierarchical)
                } else {
                    reading?.image
                }
            }
            .fontWeight(.bold)
            .foregroundStyle(liveActivityReadingTint(reading, target: $0))
        }
    }
}

private struct MinimalReadingView: View {
    var context: ActivityViewContext<ReadingAttributes>

    var reading: GlucoseReading? {
        context.state.c
    }

    var body: some View {
        if context.isOffline {
            CompactReadingArrow(context: context)
        } else {
            WithRange {
                ReadingView(reading: context.state.c)
                    .fontWeight(.bold)
                    .fontWidth(.compressed)
                    .redacted(reason: context.isOffline ? .placeholder : [])
                    .foregroundStyle(liveActivityReadingTint(reading, target: $0))
            }
        }
    }
}

private struct MainContentView: View {
    var context: ActivityViewContext<ReadingAttributes>

    @Environment(\.activityFamily) private var family
    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper
    @Default(.showChartLiveActivity) private var _showChartLiveActivity
    @Default(.debugInfo) private var debugInfo

    var showChartLiveActivity: Bool {
        _showChartLiveActivity && !context.isOffline && !debugInfo
    }

    var body: some View {
        switch family {
        case .small: smallContentView()
        case .medium: mediumContentView()
        @unknown default: mediumContentView()
        }
    }

    @ViewBuilder func smallContentView() -> some View {
        if context.isExpired == true {
            smallExpiredView()
        } else {
            ZStack {
                if !context.isOffline, let color = context.state.c?.vividColor(target: targetLower...targetUpper) {
                    Rectangle()
                        .fill(color)
                        .brightness(-0.6)
                        .opacity(0.4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack(spacing: 0) {
                    ReadingView(reading: context.state.c)
                        .font(.title.weight(.regular))
                        .layoutPriority(100)
                        .opacity(context.isOffline ? 0.5 : 1)

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 2) {
                        MinuteTimerView(context: context, relative: false)
                            .lineLimit(1)
                            .font(.footnote.bold())
                            .minimumScaleFactor(0.5)

                        if let reason = context.state.r {
                            Text(verbatim: reason)
                                .font(.footnote.bold())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .multilineTextAlignment(.trailing)
                    .layoutPriority(10)
                }
                .padding(10)
            }
        }
    }

    @ViewBuilder func mediumContentView() -> some View {
        if context.isExpired == true {
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
                        MinuteTimerView(context: context, relative: true)
                            .font(.footnote.bold())
                            .foregroundStyle(context.timestampColor)

                        if let reason = context.state.r {
                            Text(verbatim: reason)
                        } else {
                            if showChartLiveActivity {
                                if context.state.c != nil, !context.isOffline {
                                    Text("Last \(context.attributes.range.abbreviatedName)", comment: "Live Activity label showing graph range")
                                }
                            }
                        }
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .contentTransition(.numericText())
                }
                .padding([.horizontal, .top])
                .padding((showChartLiveActivity || debugInfo) ? [] : .bottom)

                if showChartLiveActivity {
                    GraphPieceView(context: context)
                        .padding(.top, 10)
                        .padding(.bottom)
                }

                if debugInfo {
                    DebugInfoList(context: context)
                        .padding(.top, 10)
                        .padding([.horizontal, .bottom])
                }
            }
        }
    }

    func mediumExpiredView() -> some View {
        MediumExpiredView(context: context)
    }

    func smallExpiredView() -> some View {
        VStack(alignment: .leading) {
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
            .font(.callout)
        }
        .fontWeight(.medium)
        .multilineTextAlignment(.center)
        .padding(10)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MediumExpiredView: View {
    var context: ActivityViewContext<ReadingAttributes>

    @Default(.debugInfo) private var debugInfo

    var body: some View {
        VStack(spacing: 0) {
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
            .padding([.horizontal, .top])
            .padding(debugInfo ? [] : .bottom)

            if debugInfo {
                DebugInfoList(context: context)
                    .padding([.horizontal, .bottom])
            }
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
    /// Effective stale level. `context.isStale` is the OS-side fallback when no push
    /// arrives by the activity's staleDate — treat it as offline.
    var staleLevel: LiveActivityState.StaleLevel {
        if isStale { return .offline }
        return state.s ?? .fresh
    }

    var isOffline: Bool {
        staleLevel == .offline
    }

    var isExpired: Bool {
        state.se ?? (state.c == nil)
    }

    var timestampColor: Color {
        switch staleLevel {
        case .fresh: .green
        case .warning: .orange
        case .stale, .offline: .red
        }
    }

    var timestamp: Text {
        if let current = state.c, !isOffline {
            Text(
                timerInterval: current.date...Date.distantFuture,
                countsDown: false
            )
            .foregroundStyle(timestampColor)
        } else {
            Text("Offline", comment: "Status indicator when Live Activity is not receiving updates")
                .foregroundStyle(.red)
        }
    }
}

private struct MinuteTimerView: View {
    var context: ActivityViewContext<ReadingAttributes>
    var relative: Bool

    @State private var offset: CGFloat = 1

    var body: some View {
        ZStack {
            if let date = context.state.c?.date, !context.isOffline {
                HStack(spacing: 0) {
                    Text(
                        timerInterval: date.addingTimeInterval(-60)...Date.distantFuture,
                        countsDown: false
                    )
                    .mask {
                        HStack(spacing: 0) {
                            Rectangle().fill()
                            Text(":00")
                                .opacity(0)
                                .background {
                                    GeometryReader { geometry in
                                        Color.clear.onChange(
                                            of: geometry.size.width,
                                            initial: true
                                        ) { _, newValue in
                                            offset = newValue
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.trailing, -offset)

                    Text(relative ? "m ago" : "m")
                }
            } else {
                Text("Offline")
            }
        }
        .foregroundStyle(context.timestampColor)
    }
}

private struct DebugInfoList: View {
    var context: ActivityViewContext<ReadingAttributes>

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: .spacing6, verticalSpacing: .spacing3) {
            GridRow {
                DebugCell(label: "Session start", value: context.state.sd?.debugFormatted)
                DebugCell(label: "Token start", value: context.state.td?.debugFormatted)
            }
            GridRow {
                DebugCell(label: "Push date", value: context.state.pd?.debugFormatted)
                DebugCell(label: "Local date", value: Date.now.debugFormatted)
            }
            GridRow {
                DebugCell(label: "Tokens", value: context.state.tc.map { "\($0)" })
                DebugCell(label: "Push-to-start", value: context.state.ps.map { $0 ? "Available" : "None" })
            }
        }
        .font(.caption2.bold())
    }
}

private struct DebugCell: View {
    var label: LocalizedStringKey
    var value: String?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: .spacing4)
            Text(verbatim: value ?? "—")
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private extension Date {
    /// A compact representation used in the Live Activity debug view that drops the year.
    var debugFormatted: String {
        formatted(.dateTime.month(.defaultDigits).day().hour().minute())
    }
}

#Preview(
    "Expanded",
    as: .dynamicIsland(.expanded),
    using: ReadingAttributes(range: .threeHours)
) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-10 * 61)), h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-5 * 61)), h: .placeholder)
    LiveActivityState(c: nil, h: [], se: true)
}

#Preview(
    "Compact",
    as: .dynamicIsland(.compact),
    using: ReadingAttributes(range: .threeHours)
) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-10 * 61)), h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-5 * 61)), h: .placeholder)
    LiveActivityState(c: nil, h: [], se: true)
}

#Preview(
    "Minimal",
    as: .dynamicIsland(.minimal),
    using: ReadingAttributes(range: .threeHours)
) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-10 * 61)), h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-5 * 61)), h: .placeholder)
    LiveActivityState(c: nil, h: [], se: true)
}

#Preview(
    "Content",
    as: .content,
    using: ReadingAttributes(range: .threeHours)
) {
    ReadingActivityConfiguration()
} contentStates: {
    LiveActivityState(c: .placeholder, h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-10 * 61)), h: .placeholder)
    LiveActivityState(c: .placeholder(date: .now.addingTimeInterval(-5 * 61)), h: .placeholder)
    LiveActivityState(c: nil, h: [], se: true)
}

private extension GlucoseReading {
    /// Pure red/green/yellow for use as a tinted background — the global
    /// low/inRange/high colors mix in pink/mint/orange which wash out at low
    /// opacity over a dark background.
    func vividColor(target: ClosedRange<Double>) -> Color {
        switch Double(value) {
        case ..<target.lowerBound: .red
        case ...target.upperBound: .green
        default: .yellow
        }
    }
}
