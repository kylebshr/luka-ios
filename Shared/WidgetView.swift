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
    var entry: Provider.Entry

    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetFamily) private var family

    private var formatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        return formatter
    }

    var body: some View {
        Button(intent: ReloadWidgetIntent()) {
            switch entry.state {
            case .reading(let reading):
                if let reading {
                    readingView(reading: reading)
                } else {
                    imageView(systemName: "icloud.slash")
                }
            case .loggedOut:
                imageView(systemName: "person.slash")
            }
        }
    }

    private func imageView(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .fontDesign(.rounded)
            .fontWeight(.semibold)
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder private func readingView(reading: GlucoseReading) -> some View {
        switch family {
        case .systemLarge, .systemMedium, .systemSmall:
            systemView(reading: reading)
        case .accessoryInline:
            inlineView(reading: reading)
        case .accessoryRectangular:
            rectangularView(reading: reading)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        default:
            fatalError()
        }
    }

    private func inlineView(reading: GlucoseReading) -> some View {
        HStack {
            Text("\(reading.value)")
            reading.trend.image
        }
    }

    private func rectangularView(reading: GlucoseReading) -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 2) {
                Text("\(reading.value)")
                reading.trend.image
            }

            Text(timestamp(for: reading.date))
        }
        .fontWeight(.medium)
        .containerBackground(.fill, for: .widget)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func systemView(reading: GlucoseReading) -> some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                Text("\(reading.value)")
                if redactionReasons.isEmpty {
                    reading.trend.image
                        .imageScale(.small)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .font(.largeTitle)
            .fontWeight(.medium)

            Spacer()

            Text(timestamp(for: reading.date))
                .font(.footnote)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentTransition(.numericText(value: Double(reading.value)))
        .containerBackground(color(for: reading.value).gradient, for: .widget)
        .fontDesign(.rounded)
        .environment(\.colorScheme, .light)
    }

    private func timestamp(for date: Date) -> String {
        if entry.date.timeIntervalSince(date) < 60 {
            return "Just now"
        } else {
            return formatter.string(from: date, to: entry.date)! + " ago"
        }
    }

    func color(for value: Int) -> Color {
        switch value {
        case ..<55:
            Color.red
        case ..<70:
            Color.orange
        case ...180:
            Color.green
        default:
            Color.yellow
        }
    }
}

extension TrendDirection {
    var image: Image? {
        switch self {
        case .none:
            nil
        case .doubleUp:
            Image("arrow.up.double")
        case .singleUp:
            Image(systemName: "arrow.up")
        case .fortyFiveUp:
            Image(systemName: "arrow.up.right")
        case .flat:
            Image(systemName: "arrow.right")
        case .fortyFiveDown:
            Image(systemName: "arrow.down.right")
        case .singleDown:
            Image(systemName: "arrow.down")
        case .doubleDown:
            Image("arrow.down.double")
        case .notComputable:
            Image(systemName: "questionmark")
        case .rateOutOfRange:
            Image(systemName: "exclamationmark")
        }
    }
}
