//
//  DexcomClient+Extensions.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/30/24.
//

import Foundation
import Dexcom

enum DexcomClientError: Error {
    case noReadings
}

extension DexcomClient {
    func getChartReadings(duration: Measurement<UnitDuration>) async throws -> [GlucoseReading]? {
        let readings = try await getGlucoseReadings(duration: duration)
            .sorted { $0.date < $1.date }

        guard !readings.isEmpty else {
            return nil
        }

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
