//
//  SensorMessage.swift
//  Luka
//
//  Vendored from G7SensorKit (LoopKit Authors). Modified for Luka.
//

import Foundation

extension Data {
    func starts(with opcode: G7Opcode) -> Bool {
        guard count > 0 else {
            return false
        }

        return self[startIndex] == opcode.rawValue
    }
}

/// A data sequence received by the sensor
protocol SensorMessage {
    init?(data: Data)
}
