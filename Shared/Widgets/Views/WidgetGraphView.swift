//
//  RectangularReadingView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/25/24.
//

import SwiftUI
import Dexcom
import Defaults

struct WidgetGraphView: View {
    let entry: GraphTimelineProvider.Entry
    let data: GlucoseGraphEntryData

    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetContentMargins) private var margins
    @Environment(\.widgetFamily) private var family

    @Default(.unit) private var unit
    @Default(.showDeltaInWidget) private var showDeltaInWidget

    private var isInStandby: Bool {
        margins.leading > 0 && margins.leading < 5
    }

    private var font: Font {
        .system(watchOS ? .footnote : .subheadline, design: .rounded)
    }

    private var graphPadding: EdgeInsets {
        switch family {
        case .systemSmall, .systemMedium, .systemLarge:
            return EdgeInsets(
                top: margins.top,
                leading: -margins.leading - 5,
                bottom: 0,
                trailing: 0
            )
        default:
            return EdgeInsets()
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: geometry.size.height > 100 ? nil : 5) {
                Button(intent: ReloadWidgetIntent()) {
                    HStack(spacing: 5) {
                        ReadingView(reading: data.current, delta: showDeltaInWidget ? data.delta : nil)
                            .invalidatableContent()
                            .fontWeight(.semibold)

                        Group {
                            HStack(spacing: 2) {
                                ViewThatFits {
                                    Text(data.current.timestamp(for: entry.date))
                                    Text(data.current.timestamp(for: entry.date, style: .abbreviated, appendRelativeText: true))
                                    Text(data.current.timestamp(for: entry.date, style: .abbreviated, appendRelativeText: false))
                                }
                                .contentTransition(.numericText())

                                Spacer(minLength: 0)

                                #if os(iOS)
                                if entry.shouldRefresh {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .imageScale(.small)
                                        .unredacted()
                                } else {
                                    Text(data.graphRangeTitle)
                                        .font(font.smallCaps())
                                }
                                #else
                                Text(data.graphRangeTitle)
                                    .font(font.smallCaps())
                                #endif
                            }
                        }
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                    }
                }

                #if os(iOS)
                let showLabels = family == .systemMedium || family == .systemLarge
                let useFullYRange = family == .systemLarge
                #else
                let showLabels = false
                let useFullYRange = false
                #endif

                LineChart(
                    range: data.configuration.graphRange,
                    readings: data.history.toLiveActivityReadings(),
                    showAxisLabels: showLabels,
                    useFullYRange: useFullYRange
                )
                .padding(graphPadding)
                .padding(.bottom, showLabels ? -margins.bottom / 2 : 0)
            }
            .font(font)
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }
}
