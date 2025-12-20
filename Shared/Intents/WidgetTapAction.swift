//
//  WidgetTapAction.swift
//  Luka
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
            .startLiveActivity: "Start Live Activity",
        ]
    }

    case refresh
    case launch
    case startLiveActivity
}

