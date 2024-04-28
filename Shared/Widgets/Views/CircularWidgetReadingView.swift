//
//  WidgetView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/24/24.
//

import Dexcom
import SwiftUI
import WidgetKit

struct CircularWidgetView : View {
    let entry: Provider.Entry
    let reading: GlucoseReading

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        Button(intent: ReloadWidgetIntent()) {
            Gauge(
                value: 0,
                label: {},
                currentValueLabel: {
                    VStack(spacing: watchOS ? -4 : -2) {
                        Text(redactionReasons.isEmpty ? reading.value.formatted() : "11")
                            .contentTransition(.numericText(value: Double(reading.value)))
                            .minimumScaleFactor(0.5)
                            .fontWeight(.bold)
                            .invalidatableContent()

                        Text(reading.timestamp(for: entry.date, style: .abbreviated))
                            .font(
                                watchOS
                                ? .system(size: 10, design: .rounded).bold()
                                : .footnote
                            )
                            .contentTransition(.numericText(value: reading.date.timeIntervalSinceNow))
                            .foregroundStyle(.secondary)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                    }
                    .padding(-2)
                }
            )
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(reading.color)
            .overlay {
                if redactionReasons.isEmpty {
                    if let rotationDegrees = rotationDegrees(for: reading.trend) {
                        arrow(degrees: rotationDegrees)
                        arrow(degrees: rotationDegrees)
                            .padding(doubleArrow ? (watchOS ? 4 : 4.5) : 0)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .fontDesign(.rounded)
        .containerBackground(.fill, for: .widget)
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
                    .font(.system(size: watchOS ? 15 : 21))
                    .fontWeight(watchOS ? .bold : .medium)
            }
            .rotationEffect(.degrees(degrees))
            .padding(watchOS ? -0.5 : -1)
    }

    var watchOS: Bool {
        #if os(watchOS)
        return true
        #else
        return false
        #endif
    }

    var doubleArrow: Bool {
        switch reading.trend {
        case .doubleUp, .doubleDown: true
        default: false
        }
    }
}
