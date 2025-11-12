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

    @Environment(\.widgetRenderingMode) private var renderingMode

    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReadingView(reading: reading)
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.regular)
                .invalidatableContent()

            Spacer(minLength: 0)

            Button(intent: ReloadWidgetIntent()) {
                WidgetButtonContent(
                    text: reading.timestamp(for: entry.date),
                    image: entry.shouldRefresh ? "arrow.triangle.2.circlepath" : ""
                )
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .containerBackground(reading.color(target: targetLower...targetUpper).gradient, for: .widget)
        .foregroundStyle(renderingMode == .fullColor ? .black : .primary)
    }
}
