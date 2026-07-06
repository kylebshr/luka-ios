//
//  DirectModeTests.swift
//  LukaTests
//
//  Created by Claude on 7/6/26.
//

import Defaults
import DexcomKit
import Foundation
import Testing
@testable import Luka
@testable import Dexcom

private func makeDirectReading(
    glucose: Int? = 120,
    trendRate: Double? = 0,
    date: Date = .now,
    timestampOffset: UInt32 = 1000
) -> DexcomKit.GlucoseReading {
    DexcomKit.GlucoseReading(
        glucose: glucose,
        trendRate: trendRate,
        date: date,
        timestampOffset: timestampOffset,
        sequence: nil,
        algorithmState: .known(.ok),
        isDisplayOnly: false,
        isBackfilled: false,
        predictedGlucose: nil,
        sensorName: "DXCMAA"
    )
}

struct DexcomKitBridgeTests {

    @Test func test_trendArrowMapping() {
        #expect(DexcomKit.TrendArrow.fallingQuickly.trendDirection == .doubleDown)
        #expect(DexcomKit.TrendArrow.falling.trendDirection == .singleDown)
        #expect(DexcomKit.TrendArrow.fallingSlightly.trendDirection == .fortyFiveDown)
        #expect(DexcomKit.TrendArrow.steady.trendDirection == .flat)
        #expect(DexcomKit.TrendArrow.risingSlightly.trendDirection == .fortyFiveUp)
        #expect(DexcomKit.TrendArrow.rising.trendDirection == .singleUp)
        #expect(DexcomKit.TrendArrow.risingQuickly.trendDirection == .doubleUp)
    }

    @Test func test_bridgedReading() {
        let date = Date.now
        let bridged = makeDirectReading(glucose: 142, trendRate: -2.5, date: date).bridged

        #expect(bridged?.value == 142)
        #expect(bridged?.trend == .singleDown)
        #expect(bridged?.date == date)
    }

    @Test func test_bridgedReadingWithoutValueIsNil() {
        #expect(makeDirectReading(glucose: nil).bridged == nil)
    }

    @Test func test_bridgedReadingWithoutTrendIsNone() {
        #expect(makeDirectReading(trendRate: nil).bridged?.trend == Dexcom.TrendDirection.none)
    }

    @Test func test_bridgingSequenceDropsValuelessReadings() {
        let readings = [
            makeDirectReading(glucose: 100, timestampOffset: 300),
            makeDirectReading(glucose: nil, timestampOffset: 600),
            makeDirectReading(glucose: 110, timestampOffset: 900),
        ]

        #expect(readings.bridged().map(\.value) == [100, 110])
    }
}

// Serialized: these tests mutate the shared `Defaults[.cachedReadings]` store.
@Suite(.serialized) struct DirectReadingStoreTests {

    private func reading(minutesAgo: Int, value: Int = 100) -> Dexcom.GlucoseReading {
        Dexcom.GlucoseReading(
            value: value,
            trend: .flat,
            date: Date(timeIntervalSinceReferenceDate: 1_000_000 - Double(minutesAgo * 60))
        )
    }

    @Test func test_mergeSortsAscendingAndDedupesByDate() {
        let existing = [reading(minutesAgo: 10, value: 100), reading(minutesAgo: 5, value: 105)]
        let new = [reading(minutesAgo: 5, value: 106), reading(minutesAgo: 0, value: 110)]

        let merged = DirectReadingStore.merge(existing: existing, new: new, cutoff: .distantPast)

        #expect(merged.map(\.value) == [100, 106, 110])
        #expect(merged == merged.sorted { $0.date < $1.date })
    }

    @Test func test_mergeTrimsToCutoff() {
        let old = reading(minutesAgo: 60)
        let recent = reading(minutesAgo: 5)
        let cutoff = recent.date.addingTimeInterval(-10 * 60)

        let merged = DirectReadingStore.merge(existing: [old], new: [recent], cutoff: cutoff)

        #expect(merged == [recent])
    }

    @Test func test_ingestUpdatesCacheAndReportsLatestChange() {
        let previousCache = Defaults[.cachedReadings]
        defer { Defaults[.cachedReadings] = previousCache }
        Defaults[.cachedReadings] = nil

        let first = Dexcom.GlucoseReading(value: 100, trend: .flat, date: .now.addingTimeInterval(-5 * 60))
        let second = Dexcom.GlucoseReading(value: 105, trend: .flat, date: .now)

        #expect(DirectReadingStore.ingest([first]))
        #expect(Defaults[.cachedReadings]?.readings == [first])
        #expect(Defaults[.cachedReadings]?.duration == DirectReadingStore.window)

        // Re-delivering the same reading is a no-op.
        #expect(!DirectReadingStore.ingest([first]))

        #expect(DirectReadingStore.ingest([second]))
        #expect(Defaults[.cachedReadings]?.latestReading == second)
    }
}

// Serialized: these tests mutate the shared `Defaults[.cachedReadings]` store.
@Suite(.serialized) struct DirectDexcomClientTests {

    @Test func test_servesCachedReadingsFilteredByDuration() async throws {
        let previousCache = Defaults[.cachedReadings]
        defer { Defaults[.cachedReadings] = previousCache }

        let old = Dexcom.GlucoseReading(value: 90, trend: .flat, date: .now.addingTimeInterval(-2 * 60 * 60))
        let recent = Dexcom.GlucoseReading(value: 120, trend: .flat, date: .now.addingTimeInterval(-5 * 60))
        Defaults[.cachedReadings] = GlucoseReadingsCache(readings: [old, recent], duration: DirectReadingStore.window)

        let client = DirectDexcomClient()

        let hour = try await client.getGlucoseReadings(duration: .init(value: 1, unit: .hours), maxCount: 100)
        #expect(hour == [recent])

        let day = try await client.getGlucoseReadings(duration: .init(value: 24, unit: .hours), maxCount: 100)
        #expect(day == [old, recent])

        let latest = try await client.getLatestGlucoseReading()
        #expect(latest == recent)
    }

    @Test func test_emptyStoreReturnsNoReadings() async throws {
        let previousCache = Defaults[.cachedReadings]
        defer { Defaults[.cachedReadings] = previousCache }
        Defaults[.cachedReadings] = nil

        let client = DirectDexcomClient()

        #expect(try await client.getGlucoseReadings(duration: .init(value: 1, unit: .hours), maxCount: 100).isEmpty)
        #expect(try await client.getLatestGlucoseReading() == nil)
    }

    @Test func test_createSessionIsUnsupported() async {
        await #expect(throws: DirectDexcomClient.DirectModeError.self) {
            _ = try await DirectDexcomClient().createSession()
        }
    }
}
