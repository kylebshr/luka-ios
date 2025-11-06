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

    var body: some View {
        ZStack {
            if let image {
                Text("\(text) \(image)")
            } else {
                Text(text)
            }
        }
        .contentTransition(.numericText(value: Double(reading?.value ?? 0)))
        .redacted(reason: reading == nil ? .placeholder : [])
        .imageScale(.small)
    }
}

#Preview {
    @Previewable @State var value = GlucoseReading(value: 89, trend: .fortyFiveUp, date: .now)

        VStack {
            ReadingView(reading: value)
                .fontWeight(.semibold)

            ReadingView(reading: nil)
                .fontWeight(.semibold)

            ReadingView(reading: value)
                .font(.largeTitle)

            ReadingView(reading: nil)
                .font(.largeTitle)

            Button("Update") {
                value = GlucoseReading(value: 92, trend: .flat, date: .now)
            }
        }
}
