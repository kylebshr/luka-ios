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
        var t: Date
        var v: Int16
    }

    var c: GlucoseReading?
    var h: [Reading]
}
