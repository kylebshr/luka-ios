//
//  DexcomClient+Extensions.swift
//  Luka
//
//  Created by Kyle Bashour on 4/30/24.
//

import Foundation
import Dexcom

enum DexcomClientError: Error {
    case noReadings
}

extension DexcomClientService {
    func getGraphReadings(duration: Measurement<UnitDuration>) async throws -> [GlucoseReading] {
        #if os(watchOS)
        let readings = if duration > .init(value: 6, unit: .hours) {
             try await getGlucoseReadings(duration: duration)
                .enumerated()
                .filter { $0.offset % 3 == 0 }
                .map { $0.1 }
                .sorted { $0.date < $1.date }
        } else {
            try await getGlucoseReadings(duration: duration)
               .sorted { $0.date < $1.date }
        }
        #else
        let readings = try await getGlucoseReadings(duration: duration)
            .sorted { $0.date < $1.date }
        #endif

        guard !readings.isEmpty else {
            throw DexcomClientError.noReadings
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
