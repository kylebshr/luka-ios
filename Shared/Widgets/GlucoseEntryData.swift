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
}

extension GlucoseReading: GlucoseEntryData {
    var current: GlucoseReading { self }
}

/// The current reading plus the one before it, so a widget can show the change
/// between them the way the Live Activity does.
struct GlucoseDeltaEntryData: GlucoseEntryData {
    var current: GlucoseReading
    var previous: GlucoseReading?

    /// Change from the previous reading, in mg/dL. Nil when there's no
    /// preceding reading, or when the gap between the two is too large (a
    /// sensor dropout) for the difference to be meaningful.
    var delta: Int? {
        guard let previous, current.date.timeIntervalSince(previous.date) <= 15 * 60 else {
            return nil
        }
        return current.value - previous.value
    }
}

struct GlucoseGraphEntryData: GlucoseEntryData {
    var configuration: GraphWidgetConfiguration
    var current: GlucoseReading
    var history: [GlucoseReading]

    var graphRangeTitle: String {
        configuration.graphRange.abbreviatedName
    }

    let targetUpperBound: Int = Int(Defaults[.targetRangeUpperBound])
    let targetLowerBound: Int = Int(Defaults[.targetRangeLowerBound])
    let graphUpperBound: Int = Int(Defaults[.graphUpperBound])
}
