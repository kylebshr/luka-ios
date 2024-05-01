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
                HStack {
                    Text(reading.timestamp(for: entry.date))
                        .contentTransition(.numericText(value: reading.date.timeIntervalSinceNow))

                    Spacer()

                    Image(systemName: "arrow.circlepath")
                        .unredacted()
                }
                .font(.footnote)
                .fontWeight(.medium)
            }
            .tint(.primary)
        }
        .standByMargins()
        .containerBackground(reading.color.gradient, for: .widget)
        .environment(\.colorScheme, .light)
    }
}

