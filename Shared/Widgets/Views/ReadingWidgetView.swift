//
//  WidgetView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/24/24.
//

import Dexcom
import SwiftUI
import WidgetKit

struct ReadingWidgetView: View {
    let entry: ReadingTimelineProvider.Entry

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

    @ViewBuilder private func readingView(for data: GlucoseDeltaEntryData) -> some View {
        switch family {
        case .systemLarge, .systemMedium, .systemSmall, .accessoryRectangular:
            SystemWidgetReadingView(entry: entry, reading: data.current)
        case .accessoryInline:
            InlineWidgetReadingView(entry: entry, reading: data.current)
        case .accessoryCircular:
            CircularWidgetView(entry: entry, reading: data.current)
        #if os(watchOS)
        case .accessoryCorner:
            CornerWidgetView(entry: entry, reading: data.current)
        #endif
        default:
            fatalError()
        }
    }
}
