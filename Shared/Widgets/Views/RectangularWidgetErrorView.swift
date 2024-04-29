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
        VStack(alignment: .leading) {
            Button(intent: ReloadWidgetIntent()) {
                HStack(spacing: 5) {
                    Image(systemName: error.image)
                    Text(error.buttonText)

                    Spacer()

                    Image(systemName: error.buttonImage)
                }
                .invalidatableContent()
            }
        }
        .fontWeight(.medium)
        .containerBackground(.fill, for: .widget)
    }
}
