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
                    Text(error.description)

                    Spacer()

                    Image(systemName: error.buttonImage)
                }
                .invalidatableContent()
            }
            .buttonStyle(.plain)
        }
        .font(.footnote)
        .fontWeight(.medium)
        .containerBackground(.fill, for: .widget)
    }
}
