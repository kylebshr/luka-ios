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

    enum StaleLevel: Int, Codable, Hashable {
        case fresh = 0
        case warning = 1
        case stale = 2
        case offline = 3
    }

    /// current
    var c: GlucoseReading?
    /// history
    var h: [Reading]
    /// sessionExpired
    var se: Bool?
    /// staleLevel
    var s: StaleLevel?
    /// sessionStartDate — when the live activity session first started
    var sd: Date?
    /// tokenStartDate — when this push token was added to the session
    var td: Date?
    /// tokenCount — number of tokens currently receiving pushes for this session
    var tc: Int?
    /// pushDate — when this push was sent
    var pd: Date?

    /// Creates a LiveActivityState from readings, filtering history to the specified range
    init(readings: [GlucoseReading], range: GraphRange) {
        let cutoff = Date.now.addingTimeInterval(-range.timeInterval)
        let filteredReadings = readings.filter { $0.date >= cutoff }
        self.c = filteredReadings.last
        self.h = filteredReadings.toLiveActivityReadings()
        self.se = nil
        self.s = nil
    }

    /// Memberwise initializer for backwards compatibility
    init(
        c: GlucoseReading?,
        h: [Reading],
        se: Bool? = nil,
        s: StaleLevel? = nil,
        sd: Date? = nil,
        td: Date? = nil,
        tc: Int? = nil,
        pd: Date? = nil
    ) {
        self.c = c
        self.h = h
        self.se = se
        self.s = s
        self.sd = sd
        self.td = td
        self.tc = tc
        self.pd = pd
    }
}
