//
//  WidgetButtonContent.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import SwiftUI

struct WidgetButtonContent: View {
    let text: String
    let image: String

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

            Spacer()

            Image(systemName: image)
                .unredacted()
        }
        .font(.footnote)
        .fontWeight(.medium)
    }
}
