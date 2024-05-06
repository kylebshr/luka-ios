//
//  GraphView+GraphRange.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/29/24.
//

import Foundation
import Dexcom

extension GraphView {
    init(
        range: GraphRange,
        readings: [GlucoseReading],
        highlight: GlucoseReading?,
        graphUpperBound: Int,
        targetRange: ClosedRange<Int>,
        roundBottomCorners: Bool,
        showMarkLabels: Bool
    ) {
        self.init(
            range: Date.now.addingTimeInterval(-range.timeInterval)...Date.now,
            readings: readings,
            highlight: highlight, 
            graphUpperBound: graphUpperBound,
            targetRange: targetRange,
            roundBottomCorners: roundBottomCorners,
            showMarkLabels: showMarkLabels
        )
    }
}
