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

struct ChartGlucoseData: GlucoseEntryData {
    var configuration: ChartWidgetConfiguration
    var current: GlucoseReading
    var history: [GlucoseChartMark]

    var chartRangeTitle: String {
        configuration.chartRange.abbreviatedName
    }

    let targetUpperBound: Int = UserDefaults.shared.targetRangeUpperBound
    let targetLowerBound: Int = UserDefaults.shared.targetRangeLowerBound
    let chartUpperBound: Int = UserDefaults.shared.chartUpperBound
}
