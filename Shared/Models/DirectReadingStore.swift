//
//  DirectReadingStore.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Defaults
import Dexcom
import Foundation

extension Notification.Name {
    /// Posted after `DirectReadingStore.ingest` changes the latest reading,
    /// so foreground view models can refresh immediately.
    static let directReadingsDidChange = Notification.Name("directReadingsDidChange")
}

/// Owns the locally persisted readings in Direct to G7 mode.
///
/// Readings are stored in `Defaults[.cachedReadings]` — the same store the
/// cloud pipeline caches into — so widgets and view models read one place
/// regardless of mode. The window is 24 hours, covering every `GraphRange`.
/// Only the app processes write here (`DirectToG7Manager` on iPhone, the
/// WatchConnectivity listener on the watch); widgets read.
enum DirectReadingStore {
    static let window: TimeInterval = 24 * 60 * 60

    /// Merges readings into the store, deduplicating by date (stable across
    /// reconnects and backfill, which re-deliver identical dates) and
    /// trimming to the rolling window. Returns true — and posts
    /// `.directReadingsDidChange` — when the latest reading changed.
    @discardableResult
    static func ingest(_ readings: [GlucoseReading]) -> Bool {
        guard !readings.isEmpty else { return false }

        let existing = Defaults[.cachedReadings]?.readings ?? []
        let merged = merge(existing: existing, new: readings, cutoff: .now.addingTimeInterval(-window))

        Defaults[.cachedReadings] = GlucoseReadingsCache(readings: merged, duration: window)

        let latestChanged = merged.last != existing.last
        if latestChanged {
            NotificationCenter.default.post(name: .directReadingsDidChange, object: nil)
        }
        return latestChanged
    }

    static func clear() {
        Defaults[.cachedReadings] = nil
    }

    /// Pure merge: new readings win on date collisions, results are sorted
    /// ascending and trimmed to `cutoff`.
    static func merge(
        existing: [GlucoseReading],
        new: [GlucoseReading],
        cutoff: Date
    ) -> [GlucoseReading] {
        var byDate: [Date: GlucoseReading] = [:]
        for reading in existing {
            byDate[reading.date] = reading
        }
        for reading in new {
            byDate[reading.date] = reading
        }

        return byDate.values
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }
}
