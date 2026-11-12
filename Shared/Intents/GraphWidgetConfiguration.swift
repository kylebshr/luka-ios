//
//  AppIntent.swift
//  WatchWidget
//
//  Created by Kyle Bashour on 4/23/24.
//

import WidgetKit
import AppIntents

struct GraphWidgetConfiguration: AccountWidgetConfiguration {
    static let title: LocalizedStringResource = "Graph Widget"
    static let description = IntentDescription("Configure graph widget settings.")

    @Parameter(title: "Graph Range", default: .eightHours)
    var graphRange: GraphRange

    @Parameter(title: "Graph Style", default: .line)
    var graphStyle: GraphStyle

    @Parameter(title: "Launch on Tap", default: .luka)
    var app: LaunchableApp

    @Parameter(
        title: "Accounts",
        description: "Shows your first account if none are chosen.",
        // Must match AccountWidgetKind.capacity(for:); LukaTests checks.
        size: [
            .systemSmall: .init(min: 0, max: 1),
            .systemMedium: .init(min: 0, max: 2),
            .systemLarge: .init(min: 0, max: 3),
            .accessoryRectangular: .init(min: 0, max: 1),
        ]
    )
    var accounts: [AccountEntity]?
}

extension GraphWidgetConfiguration {
    init(graphRange: GraphRange) {
        self.graphRange = graphRange
    }
}
