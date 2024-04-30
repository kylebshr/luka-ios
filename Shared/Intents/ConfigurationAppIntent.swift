//
//  AppIntent.swift
//  WatchWidget
//
//  Created by Kyle Bashour on 4/23/24.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Settings"
    static var description = IntentDescription("Configure Glimpse widget settings.")

    @Parameter(title: "Chart range", default: .eightHours)
    var chartRange: ChartRange
}

enum ChartRange: String, AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Chart range"
    }

    static var caseDisplayRepresentations: [ChartRange : DisplayRepresentation] {
        [
            .oneHour: "1 Hour",
            .threeHours: "3 Hours",
            .sixHours: "6 Hours",
            .eightHours: "8 Hours",
            .twelveHours: "12 Hours",
            .sixteenHours: "16 Hours",
            .twentyFourHours: "24 Hours",

        ]
    }

    case oneHour
    case threeHours
    case sixHours
    case eightHours
    case twelveHours
    case sixteenHours
    case twentyFourHours

    private var hours: Int {
        switch self {
        case .oneHour: 1
        case .threeHours: 3
        case .sixHours: 6
        case .eightHours: 8
        case .twelveHours: 12
        case .sixteenHours: 16
        case .twentyFourHours: 24
        }
    }

    var timeInterval: TimeInterval {
        60 * 60 * TimeInterval(hours)
    }

    var abbreviatedName: String {
        "\(hours)h"
    }
}
