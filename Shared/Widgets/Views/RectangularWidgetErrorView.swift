//
//  RectangularWidgetErrorView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom

struct RectangularWidgetErrorView: View {
    let error: GlucoseEntry.Error

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        Button(intent: ReloadWidgetIntent()) {
            HStack(spacing: 5) {
                Text(error.description)

                Spacer()

                #if os(watchOS)
                Image(systemName: error.image)
                #else
                Image(systemName: error.buttonImage)
                #endif
            }
            .invalidatableContent()
            .frame(maxHeight: .infinity)
        }
        #if os(watchOS)
        .buttonStyle(.plain)
        #endif
        .font(.system(size: watchOS ? 14 : 13, weight: .semibold))
        .buttonBorderShape(.roundedRectangle)
        .containerBackground(.background, for: .widget)
    }
}
