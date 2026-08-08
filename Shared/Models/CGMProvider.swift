//
//  CGMProvider.swift
//  Luka
//
//  Created by Kyle Bashour on 8/8/26.
//

import Defaults
import Foundation

/// Which CGM sharing service the signed-in account belongs to. Stored in the
/// shared defaults suite; accounts signed in before Libre support have no
/// stored value, so the default is Dexcom.
enum CGMProvider: String, Codable, Sendable, Defaults.Serializable {
    case dexcom
    case libre
}
