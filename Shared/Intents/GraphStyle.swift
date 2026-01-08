//
//  GraphStyle.swift
//  Luka
//
//  Created by Kyle Bashour on 1/8/26.
//

import AppIntents
import Foundation
import Defaults

enum GraphStyle: String, Codable, AppEnum, CaseIterable, Defaults.Serializable, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Graph Style"
    }

    static var caseDisplayRepresentations: [GraphStyle: DisplayRepresentation] {
        [
            .line: "Line",
            .dots: "Dots",
        ]
    }
    
    var id: Self { self }

    case line
    case dots

    var name: String {
        String(localized: Self.caseDisplayRepresentations[self]!.title)
    }
}
