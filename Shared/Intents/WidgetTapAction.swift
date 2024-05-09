//
//  WidgetTapAction.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/9/24.
//

import AppIntents

enum WidgetTapAction: String, AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Tap Action"
    }

    static var caseDisplayRepresentations: [WidgetTapAction : DisplayRepresentation] {
        [
            .refresh: "Refresh",
            .launch: "Launch App",
        ]
    }

    case refresh
    case launch
}

