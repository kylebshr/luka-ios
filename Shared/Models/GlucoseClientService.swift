//
//  GlucoseClientService.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/25.
//

import Foundation
import Dexcom
import Libre

/// The app's interface to a CGM data source, backed by Dexcom, LibreLinkUp,
/// or a mock. Wrappers (caching, server proxy) conform too, so everything
/// downstream is provider-agnostic.
protocol GlucoseClientService: AnyObject, Sendable {
    func getGlucoseReadings(duration: Measurement<UnitDuration>, maxCount: Int) async throws -> [GlucoseReading]
    func getLatestGlucoseReading() async throws -> GlucoseReading?
    func getCurrentGlucoseReading() async throws -> GlucoseReading?

    /// Logs in with the client's credentials, persisting the resulting
    /// session via the client's `onSessionChange`. Used to validate
    /// credentials at sign-in.
    func createSession() async throws
}

extension GlucoseClientService {
    func getGlucoseReadings() async throws -> [GlucoseReading] {
        try await getGlucoseReadings(duration: .maxGlucoseDuration, maxCount: .maxGlucoseCount)
    }

    func getGlucoseReadings(duration: Measurement<UnitDuration>) async throws -> [GlucoseReading] {
        try await getGlucoseReadings(duration: duration, maxCount: .maxGlucoseCount)
    }

    func getGlucoseReadings(maxCount: Int) async throws -> [GlucoseReading] {
        try await getGlucoseReadings(duration: .maxGlucoseDuration, maxCount: maxCount)
    }
}

/// `GlucoseClientService` over the Dexcom Share API.
final class DexcomService: GlucoseClientService {
    private let client: DexcomClient

    init(client: DexcomClient) {
        self.client = client
    }

    func getGlucoseReadings(duration: Measurement<UnitDuration>, maxCount: Int) async throws -> [GlucoseReading] {
        try await client.getGlucoseReadings(duration: duration, maxCount: maxCount)
    }

    func getLatestGlucoseReading() async throws -> GlucoseReading? {
        try await client.getLatestGlucoseReading()
    }

    func getCurrentGlucoseReading() async throws -> GlucoseReading? {
        try await client.getCurrentGlucoseReading()
    }

    func createSession() async throws {
        try await client.createSession()
    }
}

/// `GlucoseClientService` over the LibreLinkUp API. The API always returns
/// roughly the last 12 hours of readings, so duration and count are applied
/// by filtering.
final class LibreService: GlucoseClientService {
    private let client: LibreClient

    init(client: LibreClient) {
        self.client = client
    }

    func getGlucoseReadings(duration: Measurement<UnitDuration>, maxCount: Int) async throws -> [GlucoseReading] {
        let cutoff = Date.now.addingTimeInterval(-duration.converted(to: .seconds).value)
        let readings = try await client.getGlucoseReadings().filter { $0.date >= cutoff }
        return Array(readings.suffix(maxCount))
    }

    func getLatestGlucoseReading() async throws -> GlucoseReading? {
        try await client.getLatestGlucoseReading()
    }

    func getCurrentGlucoseReading() async throws -> GlucoseReading? {
        try await client.getCurrentGlucoseReading()
    }

    func createSession() async throws {
        try await client.createSession()
    }
}
