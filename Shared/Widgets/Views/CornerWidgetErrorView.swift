//
//  CornerWidgetErrorView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/18/26.
//

import SwiftUI

struct CornerWidgetErrorView: View {
    let error: GlucoseEntryError

    var body: some View {
        Button(intent: ReloadWidgetIntent()) {
            Image(systemName: error.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .widgetLabel(error.description)
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }
}

