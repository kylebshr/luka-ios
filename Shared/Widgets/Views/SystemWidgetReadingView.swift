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

    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper

    private var isInStandby: Bool {
        margins.leading > 0 && margins.leading < 10 && !showsBackground
    }

    var body: some View {
        VStack(alignment: isInStandby ? .center : .leading, spacing: 0) {
            if isInStandby {
                Spacer(minLength: 0)
            }

            ReadingView(reading: reading)
                .font(isInStandby ? .system(size: 50, design: .rounded) : .system(.largeTitle, design: .rounded))
                .fontWeight(.regular)
                .invalidatableContent()
                .minimumScaleFactor(0.5)

            if !isInStandby {
                Spacer(minLength: 0)
            }

            Button(intent: ReloadWidgetIntent()) {
                WidgetButtonContent(
                    text: reading.timestamp(for: entry.date),
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

    private var useBlackForeground: Bool {
        renderingMode == .fullColor && showsBackground
    }
}
