//
//  SystemWidgetErrorView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import WidgetKit

struct SystemWidgetErrorView: View {
    let error: GlucoseEntryError

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
                    WidgetButtonContent(error: error)
                }
            case .failedToLoad, .noRecentReadings:
                Button(intent: ReloadWidgetIntent()) {
                    WidgetButtonContent(error: error)
                        .invalidatableContent()
                }
            }
        }
        .tint(.primary)
        .containerBackground(.background, for: .widget)
    }
}
