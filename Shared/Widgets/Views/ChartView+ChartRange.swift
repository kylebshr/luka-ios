//
//  ChartView+ChartRange.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/29/24.
//

import Foundation
import Dexcom

extension ChartView {
    init(
        range: ChartRange,
        readings: [GlucoseReading],
        highlight: GlucoseReading?,
        chartUpperBound: Int,
        targetRange: ClosedRange<Int>,
        roundBottomCorners: Bool
    ) {
        self.init(
            range: Date.now.addingTimeInterval(-range.timeInterval)...Date.now,
            readings: readings,
            highlight: highlight, 
            chartUpperBound: chartUpperBound,
            targetRange: targetRange,
            roundBottomCorners: roundBottomCorners
        )
    }
}
