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

    @Parameter(title: "Account", description: "Shows your first account if not set.")
    var account: AccountEntity?
}

extension GraphWidgetConfiguration {
    init(graphRange: GraphRange) {
        self.graphRange = graphRange
    }
}
