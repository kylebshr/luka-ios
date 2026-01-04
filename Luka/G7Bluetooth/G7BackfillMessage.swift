//
//  G7BackfillMessage.swift
//  Luka
//
//  Adapted from G7SensorKit - Parse historical glucose data
//

import Foundation
import Dexcom

public struct G7BackfillMessage: Equatable, Sendable {
    //    0 1 2  3  4 5  6  7  8
    //   TTTTTT    BGBG SS    TR
    //   45a100 00 9600 06 0f fc

    public let timestamp: UInt32
    public let glucose: UInt16?
    public let glucoseIsDisplayOnly: Bool
    public let algorithmState: AlgorithmState
    public let trend: Double?
    public let data: Data

    public var hasReliableGlucose: Bool {
        return algorithmState.hasReliableGlucose
    }

    public var trendDirection: TrendDirection {
        guard let trend else { return .notComputable }

        switch trend {
        case let x where x <= -3.0: return .doubleDown
        case let x where x <= -2.0: return .singleDown
        case let x where x <= -1.0: return .fortyFiveDown
        case let x where x < 1.0: return .flat
        case let x where x < 2.0: return .fortyFiveUp
        case let x where x < 3.0: return .singleUp
        default: return .doubleUp
        }
    }

    init?(data: Data) {
        guard data.count == 9 else { return nil }

        timestamp = data[0..<4].toInt()

        let glucoseBytes = data[4..<6].to(UInt16.self)
        if glucoseBytes != 0xffff {
            glucose = glucoseBytes & 0xfff
            glucoseIsDisplayOnly = (glucoseBytes & 0xf000) > 0
        } else {
            glucose = nil
            glucoseIsDisplayOnly = false
        }

        algorithmState = AlgorithmState(rawValue: data[6])

        if data[8] == 0x7f {
            trend = nil
        } else {
            trend = Double(Int8(bitPattern: data[8])) / 10
        }

        self.data = data
    }

    /// Convert to Luka's GlucoseReading type
    public func toGlucoseReading(activationDate: Date) -> GlucoseReading? {
        guard let glucose, hasReliableGlucose else { return nil }

        let readingDate = activationDate.addingTimeInterval(TimeInterval(timestamp))

        return GlucoseReading(
            value: Int(glucose),
            trend: trendDirection,
            date: readingDate
        )
    }
}

extension G7BackfillMessage: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "G7BackfillMessage(glucose:\(String(describing: glucose)), timestamp:\(timestamp))"
    }
}
