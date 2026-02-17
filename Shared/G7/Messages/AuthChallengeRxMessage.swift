//
//  AuthChallengeRxMessage.swift
//  Luka
//
//  Vendored from G7SensorKit (LoopKit Authors). Modified for Luka.
//

import Foundation

struct AuthChallengeRxMessage: SensorMessage {
    let isAuthenticated: Bool
    let isBonded: Bool

    init?(data: Data) {
        guard data.count >= 3 else {
            return nil
        }

        guard data.starts(with: .authChallengeRx) else {
            return nil
        }

        isAuthenticated = data[1] == 0x1
        isBonded = data[2] == 0x1
    }
}
