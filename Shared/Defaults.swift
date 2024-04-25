//
//  Defaults.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/24/24.
//

import Foundation

extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.kylebashour.Glimpse")!
}

extension UserDefaults {
    subscript(key: String) -> String? {
        get { string(forKey: key) }
        set { set(newValue, forKey: key) }
    }
}

extension String {
    private static let cloudPrefix = "cloud-"

    func withCloudPrefix() -> String {
        "\(Self.cloudPrefix)\(self)"
    }

    func hasCloudPrefix() -> Bool {
        hasPrefix(Self.cloudPrefix)
    }
}
