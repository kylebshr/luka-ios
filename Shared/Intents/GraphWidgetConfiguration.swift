//
//  AppIntent.swift
//  WatchWidget
//
//  Created by Kyle Bashour on 4/23/24.
//

import WidgetKit
import AppIntents

struct GraphWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Graph Widget"
    static var description = IntentDescription("Configure graph widget settings.")

    @Parameter(title: "Graph Range", default: .eightHours)
    var graphRange: GraphRange

    @Parameter(title: "Launch on Tap", default: .luka)
    var app: LaunchableApp
}

extension GraphWidgetConfiguration {
    init(graphRange: GraphRange) {
        self.graphRange = graphRange
    }
}
