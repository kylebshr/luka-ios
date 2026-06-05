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

extension LaunchableApp {
    /// Maps an incoming widget URL to the external app it should redirect to.
    ///
    /// Widget URLs always launch the containing app (Luka) first, so Luka acts as a
    /// trampoline that re-opens the target app. Returns `nil` when the URL is Luka's
    /// own scheme or is unrecognized — in those cases there's nothing to redirect to.
    static func externalRedirect(for url: URL) -> LaunchableApp? {
        guard let match = allCases.first(where: { $0.url.scheme == url.scheme }) else {
            return nil
        }
        return match == .luka ? nil : match
    }
}
