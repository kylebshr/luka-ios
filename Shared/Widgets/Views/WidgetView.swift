//
//  WidgetView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/24/24.
//

import Dexcom
import SwiftUI
import WidgetKit

struct GlimpseWidgetEntryView: View {
    let entry: Provider.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch entry.state {
        case .reading(let reading, let readings):
            if entry.isExpired {
                readingView(for: reading, history: readings)
                    .redacted(reason: .placeholder)
            } else {
                readingView(for: reading, history: readings)
            }
        case .error(let error):
            errorView(error: error)
        }
    }

    @ViewBuilder private func readingView(for reading: GlucoseReading, history: [GlucoseReading]) -> some View {
        switch family {
        case .systemLarge, .systemMedium, .systemSmall:
            SystemWidgetReadingView(
                entry: entry,
                reading: reading,
                history: history
            )
        case .accessoryInline:
            InlineWidgetReadingView(entry: entry, reading: reading)
        case .accessoryRectangular:
            RectangularWidgetReadingView(entry: entry, reading: reading)
        case .accessoryCircular:
            CircularWidgetView(entry: entry, reading: reading)
        default:
            fatalError()
        }
    }

    @ViewBuilder private func errorView(error: GlucoseEntry.Error) -> some View {
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
