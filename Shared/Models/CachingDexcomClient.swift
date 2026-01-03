//
//  CachingDexcomClient.swift
//  Luka
//
//  Created by Claude on 01/03/26.
//

import Defaults
import Dexcom
import Foundation

/// A caching wrapper around DexcomClientService that stores readings in shared UserDefaults.
///
/// Caching strategy:
/// - Always fetches at maximum fidelity (24h) to satisfy any duration request
/// - Cache is valid if the newest reading is less than 5 minutes old
/// - Lower fidelity requests are satisfied by filtering cached readings
final class CachingDexcomClient: DexcomClientService {
    private let underlying: DexcomClientService

    var delegate: DexcomClientDelegate? {
        get { underlying.delegate }
        set { underlying.delegate = newValue }
    }

    init(wrapping client: DexcomClientService) {
        self.underlying = client
    }

    func getGlucoseReadings(
        duration: Measurement<UnitDuration>,
        maxCount: Int
    ) async throws -> [GlucoseReading] {
        let requiredSeconds = duration.converted(to: .seconds).value

        // Check if cache is valid and has required fidelity
        if let cache = Defaults[.cachedReadings],
           cache.isValid,
           cache.hasRequiredFidelity(requiredSeconds) {
            return cache.readings(for: requiredSeconds)
        }

        // Cache miss or stale - fetch at max fidelity
        let readings = try await underlying.getGlucoseReadings(
            duration: .maxGlucoseDuration,
            maxCount: .maxGlucoseCount
        )

        // Update cache (sorted by date for efficient access)
        let maxDurationSeconds = Measurement<UnitDuration>.maxGlucoseDuration
            .converted(to: .seconds).value
        let newCache = GlucoseReadingsCache(
            readings: readings.sorted { $0.date < $1.date },
            duration: maxDurationSeconds
        )
        Defaults[.cachedReadings] = newCache

        // Return filtered for requested duration
        return newCache.readings(for: requiredSeconds)
    }

    func getLatestGlucoseReading() async throws -> GlucoseReading? {
        // Check cache - any fidelity works for "latest"
        if let cache = Defaults[.cachedReadings], cache.isValid {
            return cache.latestReading
        }

        // Cache miss - fetch fresh data at max fidelity
        let readings = try await getGlucoseReadings()
        return readings.last
    }

    func getCurrentGlucoseReading() async throws -> GlucoseReading? {
        // This is the same as latest for our purposes
        try await getLatestGlucoseReading()
    }

    func createSession() async throws -> (accountID: UUID, sessionID: UUID) {
        // Session creation bypasses cache
        try await underlying.createSession()
    }
}
