//
//  Defaults.swift
//  Glimpse
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
    static let outsideUS = Key(.outsideUSKey, default: false, suite: .shared, iCloud: true)

    static let selectedRange = Key("selectedRange", default: GraphRange.twentyFourHours)
}
