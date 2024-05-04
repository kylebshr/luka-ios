//
//  URL+Persistence.swift
//  Hako
//
//  Created by Kyle Bashour on 2/19/24.
//

import Foundation

extension DiskCacheKey where Value == GlucoseChartData {
    static let chartData = DiskCacheKey(name: "cached-chart.json")
}
