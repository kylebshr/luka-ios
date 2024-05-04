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
    func getChartReadings() async throws -> GlucoseChartData? {
        let expiration = Date.now.addingTimeInterval(-60 * 60 * 24)
        let cachedData = UserDefaults.shared.cachedReadings

        let newReadings = try await getGlucoseReadings(since: cachedData?.current)
            .sorted { $0.date < $1.date }

        guard let latest = newReadings.last ?? cachedData?.current else {
            return nil
        }

        let cachedReadings = (cachedData?.history ?? [])
            .filter { $0.date > expiration }

        let data = GlucoseChartData(
            current: latest,
            history: cachedReadings + newReadings.map(GlucoseChartMark.init)
        )

        UserDefaults.shared.cachedReadings = data
        return data
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
