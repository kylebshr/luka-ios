//
//  GraphRange.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/6/24.
//

import AppIntents
import Defaults

enum GraphRange: String, Codable, AppEnum, CaseIterable, Defaults.Serializable, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Graph range"
    }

    static var caseDisplayRepresentations: [GraphRange: DisplayRepresentation] {
        [
            .oneHour: "One hour",
            .threeHours: "Three hours",
            .sixHours: "Six hours",
            .eightHours: "Eight hours",
            .twelveHours: "Twelve hours",
            .sixteenHours: "Sixteen hours",
            .twentyFourHours: "24 hours",
        ]
    }
    
    var id: Self { self }

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
        "\(hours)ʜ"
    }
}
