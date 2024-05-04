//
//  Defaults.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/24/24.
//

import Foundation
import Dexcom

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
        get { self[.chartUpperBound] ?? 300 }
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

    subscript<T: Codable>(key: String) -> T? {
        get { codable(forKey: key) }
        set { set(codable: newValue, forKey: key) }
    }

    func codable<T: Codable>(forKey key: String) -> T? {
        guard let data = data(forKey: key) else {
            return nil
        }

        return try? PropertyListDecoder().decode(T.self, from: data)
    }

    func set<T: Codable>(codable value: T, forKey key: String) {
        let data = try? PropertyListEncoder().encode(value)
        set(data, forKey: key)
    }
}
