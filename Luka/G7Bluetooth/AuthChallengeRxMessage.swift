//
//  AuthChallengeRxMessage.swift
//  Luka
//
//  Adapted from G7SensorKit - Authentication response parsing
//

import Foundation

struct AuthChallengeRxMessage: Sendable {
    let isAuthenticated: Bool
    let isBonded: Bool

    init?(data: Data) {
        guard data.count >= 3 else { return nil }
        guard data[0] == G7Opcode.authChallengeRx.rawValue else { return nil }

        isAuthenticated = data[1] == 0x1
        isBonded = data[2] == 0x1
    }
}
