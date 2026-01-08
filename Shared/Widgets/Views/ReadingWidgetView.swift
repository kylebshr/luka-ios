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

    @ViewBuilder private func readingView(for data: GlucoseReadingWithDelta) -> some View {
        switch family {
        case .systemLarge, .systemMedium, .systemSmall, .accessoryRectangular:
            SystemWidgetReadingView(entry: entry, reading: data.current, delta: data.delta)
        case .accessoryInline:
            InlineWidgetReadingView(entry: entry, reading: data.current, delta: data.delta)
        case .accessoryCircular:
            CircularWidgetView(entry: entry, reading: data.current)
        default:
            fatalError()
        }
    }
}
