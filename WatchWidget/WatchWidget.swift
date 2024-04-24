//
//  WatchWidget.swift
//  WatchWidget
//
//  Created by Kyle Bashour on 4/23/24.
//

import WidgetKit
import SwiftUI
import Dexcom
import KeychainAccess

struct WatchWidgetEntryView : View {
    var entry: Provider.Entry

    @Environment(\.redactionReasons) private var redactionReasons

    private var formatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        return formatter
    }
    
    private var isExpired: Bool {
        entry.date.timeIntervalSince(.now) > 15 * 60
    }

    var body: some View {
        switch entry.state {
        case .reading(let reading):
            if let reading {
                if entry.isExpired {
                    readingView(reading: reading)
                        .redacted(reason: .placeholder)
                } else {
                    readingView(reading: reading)
                }
            } else {
                imageView(systemName: "icloud.slash")
            }
        case .loggedOut:
            imageView(systemName: "person.slash")
        }
    }

    private func imageView(systemName: String) -> some View {
        ZStack {
            Circle().fill(.fill.secondary)
            Image(systemName: systemName)
                .font(.title3)
                .fontDesign(.rounded)
                .fontWeight(.semibold)
        }
    }

    private func readingView(reading: GlucoseReading) -> some View {
        Gauge(
            value: 0,
            label: {},
            currentValueLabel: {
                VStack(spacing: -4) {
                    Text("\(reading.value)")
                        .minimumScaleFactor(0.8)
                    if redactionReasons.isEmpty {
                        Text(timestamp(for: reading.date))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(-2)
            }
        )
        .gaugeStyle(.accessoryCircularCapacity)
        .overlay {
            if redactionReasons.isEmpty {
                if let rotationDegrees = rotationDegrees(for: reading.trend) {
                    arrow(degrees: rotationDegrees)

                    switch reading.trend {
                    case .doubleUp, .doubleDown:
                        arrow(degrees: rotationDegrees)
                            .padding(3)
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }

    private func rotationDegrees(for trend: TrendDirection) -> Double? {
        switch trend {
        case .none, .notComputable, .rateOutOfRange:
            nil
        case .doubleUp, .singleUp:
            0
        case .fortyFiveUp:
            45
        case .flat:
            90
        case .fortyFiveDown:
            135
        case .singleDown, .doubleDown:
            180
        }
    }

    private func arrow(degrees: Double) -> some View {
        Rectangle()
            .fill(.clear)
            .overlay(alignment: .top) {
                Image(systemName: "chevron.compact.up")
                    .font(.system(size: 13))
                    .fontWeight(.bold)
            }
            .rotationEffect(.degrees(degrees))
    }

    private func timestamp(for date: Date) -> String {
        if entry.date.timeIntervalSince(date) < 60 {
            return "now"
        } else {
            return formatter.string(from: date, to: entry.date)!
        }
    }
}

@main
struct WatchWidget: Widget {
    let kind: String = "WatchWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            if entry.isExpired {
                WatchWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
                    .redacted(reason: .placeholder)
            } else {
                WatchWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            }
        }
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview(as: .accessoryCircular) {
    WatchWidget()
} timeline: {
    GlucoseEntry(date: .now, state: .reading(.placeholder))
    GlucoseEntry(date: .now, state: .reading(.init(value: 94, trend: .fortyFiveUp, date: .now - 60)))
    GlucoseEntry(date: .now, state: .reading(.init(value: 102, trend: .doubleDown, date: .now - 400)))
    GlucoseEntry(date: .now.addingTimeInterval(20 * 60), state: .reading(.init(value: 183, trend: .doubleUp, date: .now - 900)))
    GlucoseEntry(date: .now, state: .reading(nil))
    GlucoseEntry(date: .now, state: .loggedOut)
}
