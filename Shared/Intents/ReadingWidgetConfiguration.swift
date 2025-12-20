//
//  ReadingWidgetConfiguration.swift
//  Luka
//
//  Created by Kyle Bashour on 5/9/24.
//

import WidgetKit
import AppIntents

struct ReadingWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Reading Widget"
    static var description = IntentDescription("Configure reading widget settings.")

    @Parameter(title: "Tap Action", default: .refresh)
    var tapAction: WidgetTapAction

    @Parameter(title: "Launch on Tap", default: .luka)
    var app: LaunchableApp

    static var parameterSummary: some ParameterSummary {
        When(\.$tapAction, .equalTo, WidgetTapAction.launch) {
            Summary {
                \.$tapAction
                \.$app
            }
        } otherwise: {
            Summary {
                \.$tapAction
            }
        }
    }

    var url: URL? {
        switch tapAction {
        case .refresh, .startLiveActivity:
            nil
        case .launch:
            app.url
        }
    }
}
