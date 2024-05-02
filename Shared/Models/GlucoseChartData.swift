//
//  GlucoseChartData.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/2/24.
//

import Foundation
import Dexcom

struct GlucoseChartData: Codable, Hashable, Equatable {
    var current: GlucoseReading
    var history: [GlucoseChartMark]
}
