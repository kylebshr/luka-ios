//
//  CachingDexcomClient.swift
//  Luka
//
//  Created by Claude on 01/03/26.
//

import Defaults
import Dexcom
import Foundation

/// A caching wrapper around DexcomClientService that stores one account's readings in shared UserDefaults.
///
/// Caching strategy:
/// - Cache is valid if the newest reading is less than 5 minutes old
/// - Lower fidelity requests can be satisfied by filtering higher-fidelity cached data
/// - Cache is updated when fetched data has higher fidelity than existing cache
final class CachingDexcomClient: DexcomClientService {
    private let underlying: any DexcomClientService
    private let cacheKey: Defaults.Key<GlucoseReadingsCache?>
    /// The Dexcom client holds its delegate weakly; keep it alive for the client's lifetime.
    private let sessionDelegate: (any DexcomClientDelegate)?

    init(
        wrapping client: any DexcomClientService,
        accountID: DexcomAccount.ID,
        sessionDelegate: (any DexcomClientDelegate)? = nil,
        suite: UserDefaults = .shared
    ) {
        self.underlying = client
        self.cacheKey = .cachedReadings(for: accountID, suite: suite)
        self.sessionDelegate = sessionDelegate
    }

    func setDelegate(_ delegate: DexcomClientDelegate?) async {
        await underlying.setDelegate(delegate)
    }

    func getGlucoseReadings(
        duration: Measurement<UnitDuration>,
        maxCount: Int
    ) async throws -> [GlucoseReading] {
        let requiredSeconds = duration.converted(to: .seconds).value

        // Check if cache is valid and has required fidelity
        if let cache = Defaults[cacheKey],
           cache.isValid,
           cache.hasRequiredFidelity(requiredSeconds) {
            return cache.readings(for: requiredSeconds)
        }

        // Cache miss or stale - fetch what was requested
        let readings = try await underlying.getGlucoseReadings(
            duration: duration,
            maxCount: maxCount
        )

        // Update cache if this fetch has higher fidelity than existing cache
        let existingDuration = Defaults[cacheKey]?.duration ?? 0
        if requiredSeconds > existingDuration {
            let newCache = GlucoseReadingsCache(
                readings: readings.sorted { $0.date < $1.date },
                duration: requiredSeconds
            )
            Defaults[cacheKey] = newCache
        }

        return readings.sorted { $0.date < $1.date }
    }

    func getLatestGlucoseReading() async throws -> GlucoseReading? {
        // Check cache - any fidelity works for "latest"
        if let cache = Defaults[cacheKey], cache.isValid {
            return cache.latestReading
        }

        // Cache miss - fetch just the latest
        return try await underlying.getLatestGlucoseReading()
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
