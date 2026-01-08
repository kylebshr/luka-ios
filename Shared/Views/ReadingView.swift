//
//  ReadingView.swift
//  Luka
//
//  Created by Kyle Bashour on 10/19/25.
//

import Foundation
import Dexcom
import SwiftUI
import Defaults

struct ReadingView: View {
    var reading: GlucoseReading?
    var delta: Int? = nil

    @Environment(\.redactionReasons) private var redactionReasons
    @Default(.unit) private var unit

    var text: String {
        (reading?.value ?? 100).formatted(.glucose(unit))
    }

    var image: Image? {
        if !redactionReasons.contains(.placeholder), let image = reading?.image {
            return image
        } else {
            return nil
        }
    }

    var deltaText: String? {
        guard !redactionReasons.contains(.placeholder), let delta else { return nil }
        return GlucoseReading.formattedDelta(delta, unit: unit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(text).contentTransition(.numericText(value: Double(reading?.value ?? 0)))
                if let image {
                    Text(verbatim: "\u{200A}") // hair space
                    image
                        .id(reading?.trend)
                        .transition(.blurReplace)
                }
            }
            .imageScale(.small)

            if let deltaText {
                Text(deltaText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(delta ?? 0)))
            }
        }
        .redacted(reason: reading == nil ? .placeholder : [])
    }
}

#Preview {
    @Previewable @State var value = GlucoseReading(value: 89, trend: .fortyFiveUp, date: .now)
    @Previewable @State var delta: Int? = 12

        VStack {
            ReadingView(reading: value, delta: delta)
                .fontWeight(.semibold)

            ReadingView(reading: value, delta: -5)
                .fontWeight(.semibold)

            ReadingView(reading: nil)
                .fontWeight(.semibold)

            ReadingView(reading: value, delta: delta)
                .font(.largeTitle)

            ReadingView(reading: nil)
                .font(.largeTitle)

            Button("Update") {
                value = GlucoseReading(
                    value: (80...120).randomElement()!,
                    trend: [
                        .flat,
                        .doubleDown,
                        .fortyFiveDown,
                        .doubleDown,
                        .fortyFiveDown
                    ].randomElement()!,
                    date: .now
                )
                delta = (-20...20).randomElement()!
            }
        }
        .animation(.default, value: value)
}
