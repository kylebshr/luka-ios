//
//  CircularWidgetErrorView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom

struct CircularWidgetErrorView: View {
    let imageName: String

    var body: some View {
        Button(intent: ReloadWidgetIntent()) {
            ZStack {
                Circle().fill(.fill.secondary)
                Image(systemName: imageName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .invalidatableContent()
            }
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }
}
