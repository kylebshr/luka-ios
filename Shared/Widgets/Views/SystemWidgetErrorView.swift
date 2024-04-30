//
//  SystemWidgetErrorView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import WidgetKit

struct SystemWidgetErrorView: View {
    let error: GlucoseEntry.Error

    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: error.image)

            Spacer()

            Text(error.description)
                .font(.subheadline)

            Spacer()

            switch error {
            case .loggedOut:
                // Not a real button, just launch the app
                Button {} label: {
                    ButtonContent(error: error)
                }
            case .failedToLoad, .noRecentReadings:
                Button(intent: ReloadWidgetIntent()) {
                    ButtonContent(error: error)
                        .invalidatableContent()
                }
            }
        }
        .containerBackground(.fill.secondary, for: .widget)
        .tint(.primary)
    }
}

private struct ButtonContent: View {
    let error: GlucoseEntry.Error

    var body: some View {
        HStack {
            Text(error.buttonText)

            Spacer()

            Image(systemName: error.buttonImage)
                .unredacted()
        }
        .font(.footnote)
        .fontWeight(.medium)
    }
}
