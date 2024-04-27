//
//  RectangularWidgetErrorView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom

struct RectangularWidgetErrorView: View {
    let imageName: String

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        Button(intent: ReloadWidgetIntent()) {
            HStack {
                Image(systemName: imageName)

                Spacer()

                Image(systemName: "arrow.circlepath")
            }
        }
        .fontWeight(.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill, for: .widget)
    }
}
