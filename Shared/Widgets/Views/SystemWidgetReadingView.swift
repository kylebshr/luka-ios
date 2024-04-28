//
//  SystemWidgetReadingView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import WidgetKit
import Dexcom

struct SystemWidgetReadingView: View {
    let entry: Provider.Entry
    let reading: GlucoseReading

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                Text("\(reading.value)")
                    .contentTransition(.numericText(value: Double(reading.value)))
                    .invalidatableContent()

                if redactionReasons.isEmpty {
                    reading.image
                        .imageScale(.small)
                        .contentTransition(.symbolEffect(.replace))
                }

                Spacer()

            }
            .font(.largeTitle)
            .fontWeight(.regular)

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .fontDesign(.rounded)
        .containerBackground(reading.color.gradient, for: .widget)
    }
}
