//
//  SystemWidgetErrorView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import WidgetKit

struct SystemWidgetErrorView: View {
    let error: GlucoseEntryError

    var body: some View {
        VStack(alignment: .center) {
            Spacer()

            Text(error.description)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

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
