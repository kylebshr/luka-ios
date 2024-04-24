//
//  GlimpseWidget.swift
//  GlimpseWidget
//
//  Created by Kyle Bashour on 4/24/24.
//

import WidgetKit
import SwiftUI
import Dexcom

struct GlimpseWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.redactionReasons) private var redactionReasons

    private var formatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        return formatter
    }

    var body: some View {
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

    private func imageView(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .fontDesign(.rounded)
            .fontWeight(.semibold)
            .containerBackground(.fill.tertiary, for: .widget)
    }

    private func readingView(reading: GlucoseReading) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(reading.value)")
                if redactionReasons.isEmpty {
                    reading.trend.image
                        .imageScale(.small)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .font(.largeTitle)
            .fontWeight(.regular)

            Spacer()

            Text(timestamp(for: reading.date))
                .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentTransition(.numericText(value: Double(reading.value)))
        .containerBackground(color(for: reading.value).gradient, for: .widget)
        .fontDesign(.rounded)
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

struct GlimpseWidget: Widget {
    let kind: String = "GlimpseWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            if entry.isExpired {
                GlimpseWidgetEntryView(entry: entry)
                    .redacted(reason: .placeholder)
            } else {
                GlimpseWidgetEntryView(entry: entry)
            }
        }
        .supportedFamilies([.systemSmall])
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

#Preview(as: .systemSmall) {
    GlimpseWidget()
} timeline: {
    GlucoseEntry(date: .now, state: .reading(.placeholder))
    GlucoseEntry(date: .now, state: .reading(.init(value: 50, trend: .fortyFiveUp, date: .now - 60)))
    GlucoseEntry(date: .now.addingTimeInterval(10 * 60), state: .reading(.init(value: 60, trend: .doubleDown, date: .now - 400)))
    GlucoseEntry(date: .now.addingTimeInterval(15 * 60), state: .reading(.init(value: 183, trend: .doubleUp, date: .now - 900)))
    GlucoseEntry(date: .now.addingTimeInterval(20 * 60), state: .reading(.init(value: 183, trend: .doubleUp, date: .now - 2000)))
    GlucoseEntry(date: .now, state: .reading(nil))
    GlucoseEntry(date: .now, state: .loggedOut)
}
