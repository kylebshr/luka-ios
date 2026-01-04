//
//  MockDexcomClient.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/25.
//

import Foundation
import Dexcom

final class MockDexcomClient: DexcomClientService, @unchecked Sendable {
    func setDelegate(_ delegate: DexcomClientDelegate?) {}

    func getGlucoseReadings(duration: Measurement<UnitDuration>, maxCount: Int) async throws -> [GlucoseReading] {
        try? await Task.sleep(for: .seconds(0.2))
        return .placeholder.suffix(maxCount).filter {
            $0.date > Date.now.addingTimeInterval(-duration.converted(to: .seconds).value)
        }
    }

    func getLatestGlucoseReading() async throws -> GlucoseReading? {
        try? await Task.sleep(for: .seconds(0.2))
        return .placeholder
    }

    func getCurrentGlucoseReading() async throws -> GlucoseReading? {
        try? await Task.sleep(for: .seconds(0.2))
        return .placeholder
    }

    func createSession() async throws -> (accountID: UUID, sessionID: UUID) {
        try? await Task.sleep(for: .seconds(2))
        return (UUID(), UUID())
    }
}
