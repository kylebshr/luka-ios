//
//  G7GlucoseMessage.swift
//  Luka
//
//  Adapted from G7SensorKit - Parse glucose readings from G7 BLE
//

import Foundation
import Dexcom

public struct G7GlucoseMessage: Equatable, Sendable {
    //    0  1  2 3 4 5  6 7  8  9 1011 1213 14 15 1617 18
    //         TTTTTTTT SQSQ       AGAG BGBG SS TR PRPR C
    // 0x4e 00 d5070000 0900 00 01 0500 6100 06 01 ffff 0e
    // TTTTTTTT = timestamp
    //     SQSQ = sequence
    //     AGAG = age
    //     BGBG = glucose
    //       SS = algorithm state
    //       TR = trend
    //     PRPR = predicted
    //        C = calibration

    public let glucose: UInt16?
    public let predicted: UInt16?
    public let glucoseIsDisplayOnly: Bool
    public let messageTimestamp: UInt32
    public let algorithmState: AlgorithmState
    public let sequence: UInt16
    public let trend: Double?
    public let data: Data
    public let age: UInt16

    public var hasReliableGlucose: Bool {
        return algorithmState.hasReliableGlucose
    }

    public var glucoseTimestamp: UInt32 {
        return messageTimestamp - UInt32(age)
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
        guard data.count >= 19 else { return nil }
        guard data[1] == 00 else { return nil }

        messageTimestamp = data[2..<6].toInt()
        sequence = data[6..<8].to(UInt16.self)
        age = data[10..<12].to(UInt16.self)

        let glucoseData = data[12..<14].to(UInt16.self)
        if glucoseData != 0xffff {
            glucose = glucoseData & 0xfff
            glucoseIsDisplayOnly = (data[18] & 0x10) > 0
        } else {
            glucose = nil
            glucoseIsDisplayOnly = false
        }

        let predictionData = data[16..<18].to(UInt16.self)
        if predictionData != 0xffff {
            predicted = predictionData & 0xfff
        } else {
            predicted = nil
        }

        algorithmState = AlgorithmState(rawValue: data[14])

        if data[15] == 0x7f {
            trend = nil
        } else {
            trend = Double(Int8(bitPattern: data[15])) / 10
        }

        self.data = data
    }

    /// Convert to Luka's GlucoseReading type
    public func toGlucoseReading(activationDate: Date) -> GlucoseReading? {
        guard let glucose, hasReliableGlucose else { return nil }

        let readingDate = activationDate.addingTimeInterval(TimeInterval(glucoseTimestamp))

        return GlucoseReading(
            value: Int(glucose),
            trend: trendDirection,
            date: readingDate
        )
    }
}

extension G7GlucoseMessage: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "G7GlucoseMessage(glucose:\(String(describing: glucose)), sequence:\(sequence), state:\(algorithmState), messageTimestamp:\(messageTimestamp), age:\(age))"
    }
}
