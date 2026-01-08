//
//  GlucoseEntryData.swift
//  Luka
//
//  Created by Kyle Bashour on 5/1/24.
//

import Dexcom
import Foundation
import Defaults

protocol GlucoseEntryData {
    var current: GlucoseReading { get }
    var delta: Int? { get }
}

extension GlucoseEntryData {
    var delta: Int? { nil }
}

extension GlucoseReading: GlucoseEntryData {
    var current: GlucoseReading { self }
}

struct GlucoseReadingWithDelta: GlucoseEntryData {
    var current: GlucoseReading
    var previous: GlucoseReading?

    var delta: Int? {
        current.delta(from: previous)
    }
}

struct GlucoseGraphEntryData: GlucoseEntryData {
    var configuration: GraphWidgetConfiguration
    var current: GlucoseReading
    var history: [GlucoseReading]

    var graphRangeTitle: String {
        configuration.graphRange.abbreviatedName
    }

    var delta: Int? {
        guard history.count >= 2 else { return nil }
        let previous = history[history.count - 2]
        return current.delta(from: previous)
    }

    let targetUpperBound: Int = Int(Defaults[.targetRangeUpperBound])
    let targetLowerBound: Int = Int(Defaults[.targetRangeLowerBound])
    let graphUpperBound: Int = Int(Defaults[.graphUpperBound])
}
