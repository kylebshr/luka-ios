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
