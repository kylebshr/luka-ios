//
//  RectangularWidgetErrorView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom

struct RectangularWidgetErrorView: View {
    let error: GlucoseEntryError

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        Button(intent: ReloadWidgetIntent()) {
            WidgetButtonContent(
                text: error.description,
                image: watchOS ? error.image : error.buttonImage
            )
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
