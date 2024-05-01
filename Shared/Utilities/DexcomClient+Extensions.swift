//
//  DexcomClient+Extensions.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/30/24.
//

import Foundation
import Dexcom

extension DexcomClient {
    func getGlucoseReadingsWithCache(maxCount: Int?) async throws -> [GlucoseReading] {
        #if os(watchOS)
        return try await getGlucoseReadings()
            .sorted { $0.date < $1.date }
        #else
        let oldestCacheDate = Date.now.addingTimeInterval(-60 * 60 * 24)
        let cachedReadings = UserDefaults.shared.cachedReadings
            .filter { $0.date >= oldestCacheDate }
            .sorted { $0.date < $1.date }

        let newReadings = try await getGlucoseReadings(since: cachedReadings.last, maxCount: maxCount)
            .sorted { $0.date < $1.date }

        let readings = cachedReadings + newReadings
        UserDefaults.shared.cachedReadings = Set(readings)

        return readings
        #endif
    }

    func getGlucoseReadings(since reading: GlucoseReading?, maxCount: Int?) async throws -> [GlucoseReading] {
        let date = reading?.date ?? .distantPast
        let seconds = abs(date.timeIntervalSinceNow).rounded()
        let duration = Measurement<UnitDuration>.init(value: seconds, unit: .seconds)
        
        guard duration > .init(value: 5, unit: .minutes) else {
            return []
        }

        return try await getGlucoseReadings(
            duration: min(duration, .maxGlucoseDuration),
            maxCount: maxCount ?? .maxGlucoseCount
        )
    }
}
