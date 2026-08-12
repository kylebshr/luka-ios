//
//  RectangularReadingDeltaView.swift
//  Luka
//
//  Created by Kyle Bashour on 08/12/26.
//

import Dexcom
import SwiftUI
import WidgetKit
import Defaults

/// The small Live Activity layout, rendered in a rectangular complication: the
/// reading and its delta pill pinned to the leading edge, the age of the
/// reading trailing. The timestamp comes from the entry's date, so the timeline
/// ticks it forward a minute at a time.
struct RectangularReadingDeltaView: View {
    let entry: ReadingDeltaTimelineProvider.Entry
    let data: GlucoseDeltaEntryData

    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper

    var body: some View {
        Group {
            if entry.widgetURL == nil {
                Button(intent: ReloadWidgetIntent()) {
                    content
                }
            } else {
                content
            }
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }

    private var content: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center) {
                // The reading is plain text here so the arrow only appears
                // once — inside the pill.
                ReadingView(reading: data.current, showsTrendArrow: false)
                    .font(.system(.title2, design: .rounded))
                    .invalidatableContent()
                    .minimumScaleFactor(0.5)

                DeltaView(
                    trend: data.current.trend,
                    delta: data.delta,
                    color: data.current.vividColor(target: targetLower...targetUpper)
                )
                .font(.footnote)
                .fontWeight(.medium)
            }
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(100)

            Spacer(minLength: 2)

            Text(
                data.current.timestamp(
                    for: entry.date,
                    style: .abbreviated,
                    appendRelativeText: false,
                    nowText: "Now"
                )
            )
            .font(.system(.footnote, design: .rounded).bold())
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .layoutPriority(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
