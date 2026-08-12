//
//  ReadingDeltaWidgetView.swift
//  Luka
//
//  Created by Kyle Bashour on 08/12/26.
//

import Dexcom
import SwiftUI
import WidgetKit

struct ReadingDeltaWidgetView: View {
    let entry: ReadingTimelineProvider.Entry

    var body: some View {
        switch entry.state {
        case .reading(let data):
            RectangularReadingDeltaView(entry: entry, data: data)
                .redacted(reason: entry.isExpired ? .placeholder : [])
                .widgetURL(entry.widgetURL)
        case .error(let error):
            WidgetErrorView(error: error)
        }
    }
}
