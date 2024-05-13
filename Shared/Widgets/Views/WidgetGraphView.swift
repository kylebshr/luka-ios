//
//  RectangularReadingView.swift
//  Glimpse
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
                top: 0,
                leading: -margins.leading / 2,
                bottom: -margins.bottom / 2,
                trailing: -margins.trailing / 2
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
                        HStack(spacing: 2) {
                            Text(data.current.value.formatted(.glucose(unit)))
                                .contentTransition(.numericText(value: Double(data.current.value)))
                                .invalidatableContent()

                            if redactionReasons.isEmpty {
                                data.current.image
                                    .imageScale(.small)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        .fontWeight(.bold)

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

                GraphView(
                    range: data.configuration.graphRange,
                    readings: data.history,
                    highlight: data.current,
                    graphUpperBound: data.graphUpperBound,
                    targetRange: data.targetLowerBound...data.targetUpperBound,
                    roundBottomCorners: !isInStandby,
                    showMarkLabels: false
                )
                .padding(graphPadding)
            }
            .font(font)
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }
}
