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

    @Parameter(
        title: "Accounts",
        description: "Shows your first account if none are chosen.",
        // Must match AccountWidgetKind.capacity(for:); LukaTests checks.
        size: [
            .systemSmall: .init(min: 0, max: 2),
            .systemMedium: .init(min: 0, max: 2),
            .systemLarge: .init(min: 0, max: 4),
            .accessoryRectangular: .init(min: 0, max: 2),
            .accessoryInline: .init(min: 0, max: 1),
            .accessoryCircular: .init(min: 0, max: 1),
            .accessoryCorner: .init(min: 0, max: 1),
        ]
    )
    var accounts: [AccountEntity]?

    static var parameterSummary: some ParameterSummary {
        When(\.$tapAction, .equalTo, WidgetTapAction.launch) {
            Summary {
                \.$tapAction
                \.$app
                \.$accounts
            }
        } otherwise: {
            Summary {
                \.$tapAction
                \.$accounts
            }
        }
    }

    var url: URL? {
        tapAction == .refresh ? nil : app.url
    }
}
