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
}
