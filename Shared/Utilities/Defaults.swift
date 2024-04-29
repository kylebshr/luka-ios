//
//  Defaults.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/24/24.
//

import Foundation

extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.kylebashour.Glimpse")!

    var outsideUS: Bool {
        get { self[.outsideUSKey] }
        set { self[.outsideUSKey] = newValue }
    }

    var targetRangeLowerBound: Int {
        get { self[.targetRangeLowerBound] ?? 70 }
        set { self[.targetRangeLowerBound] = newValue }
    }

    var targetRangeUpperBound: Int {
        get { self[.targetRangeUpperBound] ?? 180 }
        set { self[.targetRangeUpperBound] = newValue }
    }

    var chartUpperBound: Int {
        get { self[.chartUpperBound] ?? 350 }
        set { self[.chartUpperBound] = newValue }
    }
}

extension UserDefaults {
    subscript(key: String) -> String? {
        get { string(forKey: key) }
        set { set(newValue, forKey: key) }
    }

    subscript(key: String) -> Bool {
        get { bool(forKey: key) }
        set { set(newValue, forKey: key) }
    }

    subscript(key: String) -> Int? {
        get { value(forKey: key) as? Int }
        set { set(newValue, forKey: key) }
    }
}
