//
//  GraphWidgetView.swift
//  Luka
//
//  Created by Kyle Bashour on 5/1/24.
//

import Dexcom
import SwiftUI
import WidgetKit

struct GraphWidgetView: View {
    let entry: GraphTimelineProvider.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .reading(let data):
            readingView(for: data)
                .redacted(reason: entry.isExpired ? .placeholder : [])
                .widgetURL(entry.widgetURL)
        case .error(let error):
            WidgetErrorView(error: error)
        }
    }

    @ViewBuilder private func readingView(for data: GlucoseGraphEntryData) -> some View {
        switch family {
        case .systemLarge, .systemMedium, .systemSmall, .accessoryRectangular:
            WidgetGraphView(entry: entry, data: data)
        default:
            fatalError()
        }
    }
}
