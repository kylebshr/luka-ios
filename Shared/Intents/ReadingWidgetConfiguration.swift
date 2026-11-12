//
//  ReadingWidgetConfiguration.swift
//  Luka
//
//  Created by Kyle Bashour on 5/9/24.
//

import WidgetKit
import AppIntents

struct ReadingWidgetConfiguration: AccountWidgetConfiguration {
    static let title: LocalizedStringResource = "Reading Widget"
    static let description = IntentDescription("Configure reading widget settings.")

    @Parameter(title: "Tap Action", default: .refresh)
    var tapAction: WidgetTapAction

    @Parameter(title: "Launch on Tap", default: .luka)
    var app: LaunchableApp

    @Parameter(title: "Account", description: "Shows your first account if not set.")
    var account: AccountEntity?

    static var parameterSummary: some ParameterSummary {
        When(\.$tapAction, .equalTo, WidgetTapAction.launch) {
            Summary {
                \.$tapAction
                \.$app
                \.$account
            }
        } otherwise: {
            Summary {
                \.$tapAction
                \.$account
            }
        }
    }

    var url: URL? {
        tapAction == .refresh ? nil : app.url
    }
}
