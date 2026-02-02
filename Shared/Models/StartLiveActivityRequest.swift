//
//  PushEnvironment.swift
//  Luka
//
//  Created by Kyle Bashour on 10/19/25.
//


import Foundation
import Dexcom

enum PushEnvironment: String, Codable {
    case development
    case production

    static var current: Self {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }
}

struct LiveActivityPreferences: Codable {
    var targetRange: ClosedRange<Int>
    var unit: GlucoseFormatter.Unit
    var sendStaleUpdates: Bool?
}

struct StartLiveActivityRequest: Codable {
    var pushToken: String
    var environment: PushEnvironment
    var username: String?
    var password: String?
    var accountLocation: AccountLocation
    var duration: TimeInterval
    var preferences: LiveActivityPreferences?
}
