//
//  ExtendedVersionMessage.swift
//  Luka
//
//  Vendored from G7SensorKit (LoopKit Authors). Modified for Luka.
//

import Foundation

public struct ExtendedVersionMessage: SensorMessage, Equatable, Sendable {
    public let sessionLength: TimeInterval
    public let warmupDuration: TimeInterval
    public let algorithmVersion: UInt32
    public let hardwareVersion: UInt8
    public let maxLifetimeDays: UInt16

    public let data: Data

    init?(data: Data) {
        self.data = data

        guard data.starts(with: .extendedVersionTx) else {
            return nil
        }

        guard data.count >= 15 else {
            return nil
        }

        sessionLength = TimeInterval(data[2..<6].to(UInt32.self))
        warmupDuration = TimeInterval(data[6..<8].to(UInt16.self))
        algorithmVersion = data[8..<12].to(UInt32.self)
        hardwareVersion = data[12]
        maxLifetimeDays = data[13..<15].to(UInt16.self)
    }
}

extension ExtendedVersionMessage: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "ExtendedVersionMessage(sessionLength:\(sessionLength), warmupDuration:\(warmupDuration) algorithmVersion:\(algorithmVersion) hardwareVersion:\(hardwareVersion) maxLifetimeDays:\(maxLifetimeDays))"
    }
}
