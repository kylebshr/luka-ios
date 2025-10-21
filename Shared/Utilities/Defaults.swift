//
//  Defaults.swift
//  Luka
//
//  Created by Kyle Bashour on 4/24/24.
//

import Foundation
import Dexcom
import Defaults

extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.kylebashour.Glimpse")!
}

extension Defaults.Keys {
    static let targetRangeLowerBound = Key<Double>(.targetRangeLowerBound, default: 70, suite: .shared, iCloud: true)
    static let targetRangeUpperBound = Key<Double>(.targetRangeUpperBound, default: 180, suite: .shared, iCloud: true)
    static let graphUpperBound = Key<Double>(.graphUpperBound, default: 300, suite: .shared, iCloud: true)
    static let accountLocation = Key<AccountLocation?>(.accountLocation, default: nil, suite: .shared, iCloud: true)
    static let unit = Key<GlucoseFormatter.Unit>("unit", default: .mgdl, suite: .shared, iCloud: true)

    static let selectedRange = Key("selectedRange", default: GraphRange.eightHours)
    static let sessionHistory = Key<[DexcomSessionHistoryEntry]>(
        .sessionHistory,
        default: [],
        suite: .shared,
        iCloud: true
    )
}

extension AccountLocation: Defaults.Serializable {}
extension GlucoseFormatter.Unit: Defaults.Serializable {}

struct DexcomSessionHistoryEntry: Defaults.Serializable, Identifiable, Codable, Equatable {
    var sessionID: UUID
    var recordedAt: Date
    var source: String

    var id: UUID { sessionID }

    init(sessionID: UUID, recordedAt: Date = .now, source: String) {
        self.sessionID = sessionID
        self.recordedAt = recordedAt
        self.source = source

    }
}

enum DexcomSessionHistory {
    static func record(sessionID: UUID, at date: Date = .now, source: String) {
        var history = Defaults[.sessionHistory]

        if history.last?.sessionID == sessionID {
            return
        }

        history.append(.init(sessionID: sessionID, recordedAt: date, source: source))
        Defaults[.sessionHistory] = history
    }
}
