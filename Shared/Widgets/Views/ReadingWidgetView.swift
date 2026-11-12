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
        // Every watch family shows one account.
        #if os(iOS)
        if entry.showsMultipleAccounts {
            MultiAccountReadingWidgetView(entry: entry)
        } else {
            singleAccountView
        }
        #else
        singleAccountView
        #endif
    }

    @ViewBuilder private var singleAccountView: some View {
        switch entry.state {
        case .reading(let reading):
            readingView(for: reading)
                .redacted(reason: entry.isExpired ? .placeholder : [])
                .widgetURL(entry.widgetURL)
        case .error(let error):
            WidgetErrorView(error: error)
        }
    }

    @ViewBuilder private func readingView(for reading: GlucoseReading) -> some View {
        switch family {
        case .systemLarge, .systemMedium, .systemSmall, .accessoryRectangular:
            SystemWidgetReadingView(entry: entry, reading: reading)
        case .accessoryInline:
            InlineWidgetReadingView(entry: entry, reading: reading)
        case .accessoryCircular:
            CircularWidgetView(entry: entry, reading: reading)
        #if os(watchOS)
        case .accessoryCorner:
            CornerWidgetView(entry: entry, reading: reading)
        #endif
        default:
            fatalError()
        }
    }
}
