//
//  LaunchableAppIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 5/9/24.
//

import AppIntents
import Defaults

enum LaunchableApp: String, Codable, AppEnum, CaseIterable, Defaults.Serializable, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Launch App"
    }

    static var caseDisplayRepresentations: [LaunchableApp : DisplayRepresentation] {
        [
            .luka: "Luka",
            .g7: "Dexcom G7",
            .g6: "Dexcom G6",
            .clarity: "Dexcom Clarity",
            .sugarmate: "Sugarmate",
            .omnipod: "Omnipod",
        ]
    }

    var id: Self { self }

    var url: URL {
        let string = switch self {
        case .luka:
            "luka://"
        case .g7:
            "dexcomg7://"
        case .g6:
            "dexcomg6://"
        case .clarity:
            "claritymobile://"
        case .sugarmate:
            "sugarmate://"
        case .omnipod:
            "omnipod://"
        }

        return URL(string: string)!
    }

    case luka
    case g7
    case g6
    case clarity
    case sugarmate
    case omnipod
}
