//
//  SystemWidgetReadingView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import SwiftUI
import WidgetKit
import Dexcom

struct SystemWidgetReadingView: View {
    let entry: ReadingTimelineProvider.Entry
    let reading: GlucoseReading

    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetContentMargins) private var widgetContentMargins

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(reading.value.formatted())
                        .contentTransition(.numericText(value: Double(reading.value)))
                        .invalidatableContent()

                    if redactionReasons.isEmpty {
                        reading.image
                            .imageScale(.small)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .font(.system(.largeTitle, design: .rounded))
                .fontWeight(.medium)

                Spacer()
            }

            Spacer()

            Button(intent: ReloadWidgetIntent()) {
                WidgetButtonContent(
                    text: reading.timestamp(for: entry.date),
                    image: "arrow.circlepath"
                )
            }
            .buttonStyle(.plain)
        }
        .standByMargins()
        .containerBackground(reading.color.gradient, for: .widget)
        .environment(\.colorScheme, .light)
    }
}

