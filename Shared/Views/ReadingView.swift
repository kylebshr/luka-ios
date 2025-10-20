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

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .contentTransition(.numericText(value: Double(reading?.value ?? 0)))

            if !redactionReasons.contains(.placeholder), let image = reading?.image {
                Text(" ")
                image.imageScale(.small)
                    .contentTransition(.symbolEffect(.replace))
                    .transition(.blurReplace)
            }
        }
        .redacted(reason: reading == nil ? .placeholder : [])
    }
}

#Preview {
    VStack {
        ReadingView(reading: .placeholder)
            .fontWeight(.semibold)

        ReadingView(reading: nil)
            .fontWeight(.semibold)

        ReadingView(reading: .placeholder)
            .font(.largeTitle)

        ReadingView(reading: nil)
            .font(.largeTitle)
    }
}
