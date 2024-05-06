//
//  GlucoseEntryData.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import Dexcom
import Foundation

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

    let targetUpperBound: Int = UserDefaults.shared.targetRangeUpperBound
    let targetLowerBound: Int = UserDefaults.shared.targetRangeLowerBound
    let graphUpperBound: Int = UserDefaults.shared.graphUpperBound
}
