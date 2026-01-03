//
//  GlucoseReadingsCache.swift
//  Luka
//
//  Created by Claude on 01/03/26.
//

import Defaults
import Dexcom
import Foundation

/// Cache for glucose readings, stored sorted by date ascending (oldest first, newest last).
struct GlucoseReadingsCache: Codable, Defaults.Serializable {
    let readings: [GlucoseReading]
    let duration: TimeInterval

    /// Returns true if the newest reading is less than 5 minutes old
    var isValid: Bool {
        guard let newest = readings.last else {
            return false
        }
        return Date.now.timeIntervalSince(newest.date) < 5 * 60
    }

    /// Returns true if the cached duration covers the required duration
    func hasRequiredFidelity(_ requiredDuration: TimeInterval) -> Bool {
        duration >= requiredDuration
    }

    /// Filters readings to only include those within the specified duration from now
    func readings(for requestedDuration: TimeInterval) -> [GlucoseReading] {
        let cutoff = Date.now.addingTimeInterval(-requestedDuration)
        return readings.filter { $0.date >= cutoff }
    }

    /// Returns the most recent reading
    var latestReading: GlucoseReading? {
        readings.last
    }
}
