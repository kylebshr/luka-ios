//
//  DexcomClient+Extensions.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/30/24.
//

import Foundation
import Dexcom

extension DexcomClient {
    func getGlucoseReadingsWithCache() async throws -> [GlucoseReading] {
        let oldestCacheDate = Date.now.addingTimeInterval(-60 * 60 * 24)
        let cachedReadings = UserDefaults.shared.cachedReadings
            .filter { $0.date >= oldestCacheDate }
            .sorted { $0.date < $1.date }

        let newReadings = try await getGlucoseReadings(since: cachedReadings.last)
            .sorted { $0.date < $1.date }

        let readings = cachedReadings + newReadings
        UserDefaults.shared.cachedReadings = Set(readings)

        return readings
    }

    func getGlucoseReadings(since reading: GlucoseReading?) async throws -> [GlucoseReading] {
        let date = reading?.date ?? .distantPast
        let seconds = abs(date.timeIntervalSinceNow).rounded()
        let duration = Measurement<UnitDuration>.init(value: seconds, unit: .seconds)
        
        guard duration > .init(value: 5, unit: .minutes) else {
            return []
        }

        return try await getGlucoseReadings(duration: min(duration, .maxGlucoseDuration))
    }
}
