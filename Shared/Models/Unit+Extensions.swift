//
//  Unit+Extensions.swift
//  Luka
//
//  Created by Kyle Bashour on 10/17/25.
//

import Dexcom

extension GlucoseFormatter.Unit {
    var text: String {
        switch self {
        case .mgdl:
            "mg/dl"
        case .mmolL:
            "mmol/L"
        }
    }
}
