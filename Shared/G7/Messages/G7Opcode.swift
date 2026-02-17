//
//  G7Opcode.swift
//  Luka
//
//  Vendored from G7SensorKit (LoopKit Authors). Modified for Luka.
//

import Foundation

enum G7Opcode: UInt8 {
    case authChallengeRx = 0x05
    case sessionStopTx = 0x28
    case glucoseTx = 0x4e
    case extendedVersionTx = 0x52
    case extendedVersionRx = 0x53
    case backfillFinished = 0x59
}
