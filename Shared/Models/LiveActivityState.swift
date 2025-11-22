//
//  LiveActivityState.swift
//  Luka
//
//  Created by Kyle Bashour on 10/18/25.
//

import Foundation
import Dexcom

struct LiveActivityState: Codable, Hashable {
    struct Reading: Codable, Hashable {
        /// timestamp
        var t: Date
        /// value
        var v: Int16
    }

    /// current
    var c: GlucoseReading?
    /// history
    var h: [Reading]
    /// sessionExpired
    var se: Bool?
}
