//
//  WidgetErrorView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import SwiftUI

struct WidgetErrorView: View {
    let error: GlucoseEntryError

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemLarge, .systemMedium, .systemSmall:
            SystemWidgetErrorView(error: error)
        case .accessoryInline:
            Image(systemName: error.image)
        case .accessoryRectangular:
            RectangularWidgetErrorView(error: error)
        case .accessoryCircular:
            CircularWidgetErrorView(imageName: error.image)
        default:
            fatalError()
        }
    }
}
