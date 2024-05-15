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
}

extension AccountLocation: Defaults.Serializable {}
extension GlucoseFormatter.Unit: Defaults.Serializable {}
