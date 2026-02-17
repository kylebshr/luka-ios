//
//  G7BackfillMessage.swift
//  Luka
//
//  Vendored from G7SensorKit (LoopKit Authors). Modified for Luka.
//

import Foundation

public struct G7BackfillMessage: Equatable, Sendable {
    public let timestamp: UInt32 // Seconds since pairing
    public let glucose: UInt16?
    public let glucoseIsDisplayOnly: Bool
    public let algorithmState: AlgorithmState
    public let trend: Double?

    public let data: Data

    public var hasReliableGlucose: Bool {
        return algorithmState.hasReliableGlucose
    }

    init?(data: Data) {
        //    0 1 2  3  4 5  6  7  8
        //   TTTTTT    BGBG SS    TR
        //   45a100 00 9600 06 0f fc

        guard data.count == 9 else {
            return nil
        }

        timestamp = data[0..<3].toInt()
        let glucoseBytes = data[4..<6].to(UInt16.self)

        if glucoseBytes != 0xffff {
            glucose = glucoseBytes & 0xfff
        } else {
            glucose = nil
        }

        glucoseIsDisplayOnly = data[7] & 0x10 != 0
        algorithmState = AlgorithmState(rawValue: data[6])

        if data[8] == 0x7f {
            trend = nil
        } else {
            trend = Double(Int8(bitPattern: data[8])) / 10
        }

        self.data = data
    }
}

extension G7BackfillMessage: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "G7BackfillMessage(glucose:\(String(describing: glucose)), glucoseIsDisplayOnly:\(glucoseIsDisplayOnly) timestamp:\(timestamp), data:\(data.hexadecimalString))"
    }
}
