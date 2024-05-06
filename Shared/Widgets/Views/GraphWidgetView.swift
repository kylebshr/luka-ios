//
//  GraphWidgetView.swift
//  Glimpse
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
        case .error(let error):
            WidgetErrorView(error: error)
        }
    }

    @ViewBuilder private func readingView(for data: GlucoseGraphEntryData) -> some View {
        switch family {
        #if os(iOS)
        case .systemLarge, .systemMedium, .systemSmall:
            WidgetGraphView(entry: entry, data: data)
        #endif
        case .accessoryRectangular:
            WidgetGraphView(entry: entry, data: data)
        default:
            fatalError()
        }
    }
}
