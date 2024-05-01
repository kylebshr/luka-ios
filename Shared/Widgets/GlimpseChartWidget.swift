//
//  GlimpseChartWidget.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import WidgetKit
import SwiftUI
import Dexcom

struct GlimpseChartWidget: Widget {
    let kind: String = "GlimpseChartWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ChartWidgetAppIntent.self,
            provider: ChartTimelineProvider()
        ) { entry in
            ChartWidgetView(entry: entry)
        }
        .supportedFamilies(families)
        .configurationDisplayName("Reading Chart")
    }

    private var families: [WidgetFamily] {
        #if os(watchOS)
        [
            .accessoryRectangular,
        ]
        #else
        [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
        ]
        #endif
    }
}
