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

    /// Creates a LiveActivityState from readings, filtering history to the specified range
    init(readings: [GlucoseReading], range: GraphRange) {
        let cutoff = Date.now.addingTimeInterval(-range.timeInterval)
        let filteredReadings = readings.filter { $0.date >= cutoff }
        self.c = filteredReadings.last
        self.h = filteredReadings.toLiveActivityReadings()
        self.se = nil
    }

    /// Memberwise initializer for backwards compatibility
    init(c: GlucoseReading?, h: [Reading], se: Bool? = nil) {
        self.c = c
        self.h = h
        self.se = se
    }

    /// Returns the delta between current and previous reading, if available
    var delta: Int? {
        guard h.count >= 2 else { return nil }
        let current = h[h.count - 1]
        let previous = h[h.count - 2]
        return Int(current.v) - Int(previous.v)
    }
}
