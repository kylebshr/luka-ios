//
//  G7ConnectionState+Display.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import DexcomKit
import SwiftUI

extension G7ConnectionState {
    var text: LocalizedStringKey {
        switch self {
        case .idle:
            "Off"
        case .bluetoothUnavailable(.poweredOff):
            "Bluetooth is off"
        case .bluetoothUnavailable(.unauthorized):
            "Bluetooth not allowed"
        case .bluetoothUnavailable(.unsupported):
            "Bluetooth unsupported"
        case .bluetoothUnavailable(.resetting), .bluetoothUnavailable(.unknown):
            "Bluetooth unavailable"
        case .scanning:
            "Scanning"
        case .connecting:
            "Connecting"
        case .authenticating:
            "Authenticating"
        case .connected:
            "Connected"
        case .waitingForReading:
            "Waiting for next reading"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .idle:
            .gray
        case .bluetoothUnavailable:
            .lowColor
        case .scanning, .connecting, .authenticating:
            .highColor
        case .connected, .waitingForReading:
            .inRangeColor
        }
    }
}

extension DexcomKit.TrendArrow {
    var image: Image {
        switch self {
        case .fallingQuickly:
            Image("arrow.down.double")
        case .falling:
            Image(systemName: "arrow.down")
        case .fallingSlightly:
            Image(systemName: "arrow.down.right")
        case .steady:
            Image(systemName: "arrow.right")
        case .risingSlightly:
            Image(systemName: "arrow.up.right")
        case .rising:
            Image(systemName: "arrow.up")
        case .risingQuickly:
            Image("arrow.up.double")
        }
    }
}
