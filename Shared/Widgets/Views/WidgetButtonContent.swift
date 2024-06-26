//
//  WidgetButtonContent.swift
//  Luka
//
//  Created by Kyle Bashour on 5/1/24.
//

import SwiftUI

struct WidgetButtonContent: View {
    let text: String
    let image: String

    private var font: Font {
        .system(watchOS ? .footnote : .subheadline, design: .rounded)
    }

    init(text: String, image: String) {
        self.text = text
        self.image = image
    }

    init(error: GlucoseEntryError) {
        self.text = error.buttonText
        self.image = error.buttonImage
    }

    var body: some View {
        HStack {
            Text(text)
                .contentTransition(.numericText())

            Spacer()

            Image(systemName: image)
                .unredacted()
        }
        .font(font)
        .fontWeight(.medium)
    }
}
