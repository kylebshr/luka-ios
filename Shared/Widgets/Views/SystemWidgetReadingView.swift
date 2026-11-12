//
//  SystemWidgetReadingView.swift
//  Luka
//
//  Created by Kyle Bashour on 5/1/24.
//

import SwiftUI
import WidgetKit
import Dexcom
import Defaults

struct SystemWidgetReadingView: View {
    let entry: ReadingTimelineProvider.Entry
    let reading: GlucoseReading

    @Environment(\.widgetContentMargins) private var margins
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) var showsBackground
    @Environment(\.widgetFamily) private var family

    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper

    private var isInStandby: Bool {
        margins.leading > 0 && margins.leading < 10 && !showsBackground
    }

    /// The account's name, when several are signed in and there's room for it.
    private var accountName: String? {
        guard !isInStandby, family != .accessoryRectangular else { return nil }
        return entry.accountName
    }

    var body: some View {
        VStack(alignment: isInStandby ? .center : .leading, spacing: 0) {
            if isInStandby {
                Spacer(minLength: 0)
            }

            // Matches a multi-account tile: name at the top, reading at the bottom.
            if let accountName {
                Text(verbatim: accountName)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .unredacted()

                Spacer(minLength: 0)
            }

            ReadingView(reading: reading)
                .font(isInStandby ? .system(size: 50, design: .rounded) : .system(.largeTitle, design: .rounded))
                .fontWeight(isInStandby ? .medium : .regular)
                .invalidatableContent()
                .minimumScaleFactor(0.5)
                .foregroundStyle(readingColor)

            if !isInStandby && accountName == nil {
                Spacer(minLength: 0)
            }

            Button(intent: ReloadWidgetIntent()) {
                WidgetButtonContent(
                    text: timestamp,
                    image: entry.shouldRefresh ? "arrow.triangle.2.circlepath" : nil
                )
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isInStandby {
                Spacer(minLength: 0)
            }
        }
        .containerBackground(reading.color(target: targetLower...targetUpper).gradient, for: .widget)
        .foregroundStyle(useBlackForeground ? .black : .primary)
        .frame(maxWidth: .infinity, alignment: isInStandby ? .center : .leading)
    }

    private var timestamp: String {
        let timestamp = reading.timestamp(for: entry.date)
        // The Lock Screen has no room for a name above the reading.
        if family == .accessoryRectangular, !isInStandby, let name = entry.accountName {
            return "\(name) · \(reading.timestamp(for: entry.date, style: .abbreviated))"
        }
        return timestamp
    }

    private var useBlackForeground: Bool {
        renderingMode == .fullColor && showsBackground
    }

    private var readingColor: AnyShapeStyle {
        if isInStandby {
            if renderingMode == .fullColor {
                AnyShapeStyle(reading.color(target: targetLower...targetUpper).gradient)
            } else {
                AnyShapeStyle(Color.primary)
            }
        } else {
            AnyShapeStyle(Color.black)
        }
    }
}
