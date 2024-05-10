//
//  SystemWidgetReadingView.swift
//  Glimpse
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

    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetContentMargins) private var widgetContentMargins
    @Environment(\.widgetRenderingMode) private var renderingMode

    @Default(.unit) private var unit

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(reading.value.formatted(.glucose(unit)))
                        .contentTransition(.numericText(value: Double(reading.value)))
                        .invalidatableContent()

                    if redactionReasons.isEmpty {
                        reading.image
                            .imageScale(.small)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .font(.largeTitle)
                .fontWeight(.regular)

                Spacer()
            }

            Spacer(minLength: 0)

            Button(intent: ReloadWidgetIntent()) {
                WidgetButtonContent(
                    text: reading.timestamp(for: entry.date),
                    image: entry.shouldRefresh ? "arrow.triangle.2.circlepath" : ""
                )
            }
            .buttonStyle(.plain)
        }
        .containerBackground(reading.color.gradient, for: .widget)
        .foregroundStyle(renderingMode == .fullColor ? .black : .primary)
    }
}

