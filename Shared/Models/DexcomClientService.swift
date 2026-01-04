//
//  DexcomClientService.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/25.
//

import Foundation
import Dexcom

protocol DexcomClientService: AnyObject, Sendable {
    func setDelegate(_ delegate: DexcomClientDelegate?)

    func getGlucoseReadings(duration: Measurement<UnitDuration>, maxCount: Int) async throws -> [GlucoseReading]
    func getLatestGlucoseReading() async throws -> GlucoseReading?
    func getCurrentGlucoseReading() async throws -> GlucoseReading?

    func createSession() async throws -> (accountID: UUID, sessionID: UUID)
}

extension DexcomClientService {
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
