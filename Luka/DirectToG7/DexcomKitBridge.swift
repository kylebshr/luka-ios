//
//  DexcomKitBridge.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Dexcom
import DexcomKit
import Foundation

extension DexcomKit.TrendArrow {
    /// The cloud model's equivalent trend bucket.
    var trendDirection: Dexcom.TrendDirection {
        switch self {
        case .fallingQuickly: .doubleDown
        case .falling: .singleDown
        case .fallingSlightly: .fortyFiveDown
        case .steady: .flat
        case .risingSlightly: .fortyFiveUp
        case .rising: .singleUp
        case .risingQuickly: .doubleUp
        }
    }
}

extension DexcomKit.GlucoseReading {
    /// The reading as the app's cloud model, which everything downstream of
    /// `DexcomClientService` consumes; nil when the sensor produced no
    /// glucose value (warmup, algorithm faults).
    var bridged: Dexcom.GlucoseReading? {
        guard let glucose else { return nil }
        return Dexcom.GlucoseReading(
            value: glucose,
            trend: trendArrow?.trendDirection ?? .none,
            date: date
        )
    }
}

extension Sequence where Element == DexcomKit.GlucoseReading {
    /// Bridges to the cloud model, dropping value-less readings.
    func bridged() -> [Dexcom.GlucoseReading] {
        compactMap(\.bridged)
    }
}
