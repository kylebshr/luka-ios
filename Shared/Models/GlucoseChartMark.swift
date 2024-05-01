//
//  GlucoseChartMark.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import Foundation
import Dexcom

struct GlucoseChartMark: Codable, Hashable, Identifiable, Equatable {
    var id: Self { self }

    var value: Int
    var date: Date

    init(value: Int, date: Date) {
        self.value = value
        self.date = date
    }

    init(_ reading: GlucoseReading) {
        self.value = reading.value
        self.date = reading.date
    }
}
