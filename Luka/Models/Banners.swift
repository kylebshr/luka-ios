//
//  Banners.swift
//  Luka
//
//  Created by Kyle Bashour on 12/14/25.
//

import Foundation

struct Banners: Codable {
    var banners: [Banner]
    var minVersion: String?

    var requiresForceUpgrade: Bool {
        guard let minVersion else { return false }
        return SemanticVersion(Bundle.main.version) < SemanticVersion(minVersion)
    }
}

struct Banner: Codable, Equatable, Identifiable {
    var id: String
    var title: String?
    var body: String?
    var minVersion: String?
    var maxVersion: String?

    var isWithinVersionRange: Bool {
        let appVersion = SemanticVersion(Bundle.main.version)

        if let minVersion, appVersion < SemanticVersion(minVersion) {
            return false
        }

        if let maxVersion, appVersion > SemanticVersion(maxVersion) {
            return false
        }

        return true
    }
}

struct SemanticVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ versionString: String) {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        self.major = components.count > 0 ? components[0] : 0
        self.minor = components.count > 1 ? components[1] : 0
        self.patch = components.count > 2 ? components[2] : 0
    }

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
