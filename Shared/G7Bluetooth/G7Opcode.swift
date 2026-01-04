//
//  G7Opcode.swift
//  Luka
//
//  Adapted from G7SensorKit - BLE message opcodes
//

import Foundation

enum G7Opcode: UInt8 {
    case authChallengeRx = 0x05
    case glucoseTx = 0x4e
    case backfillFinished = 0x59
}
