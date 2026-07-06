//
//  DirectDexcomClient.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Defaults
import Dexcom
import Foundation

/// Serves locally persisted readings in Direct to G7 mode; never touches the
/// network. The store is fed by the app process — `DirectToG7Manager` on
/// iPhone, the WatchConnectivity listener on the watch — so widgets and view
/// models can read through the same `DexcomClientService` seam as cloud mode.
final class DirectDexcomClient: DexcomClientService {
    enum DirectModeError: Error {
        /// Dexcom Share sessions don't exist in Direct to G7 mode.
        case sessionsUnsupported
    }

    func setDelegate(_ delegate: DexcomClientDelegate?) async {
        // No sessions to rotate in direct mode.
    }

    func getGlucoseReadings(
        duration: Measurement<UnitDuration>,
        maxCount: Int
    ) async throws -> [GlucoseReading] {
        let seconds = duration.converted(to: .seconds).value
        let readings = Defaults[.cachedReadings]?.readings(for: seconds) ?? []
        // Stored ascending; keep the newest when trimming to maxCount.
        return Array(readings.suffix(maxCount))
    }

    func getLatestGlucoseReading() async throws -> GlucoseReading? {
        Defaults[.cachedReadings]?.latestReading
    }

    func getCurrentGlucoseReading() async throws -> GlucoseReading? {
        try await getLatestGlucoseReading()
    }

    func createSession() async throws -> (accountID: UUID, sessionID: UUID) {
        throw DirectModeError.sessionsUnsupported
    }
}
