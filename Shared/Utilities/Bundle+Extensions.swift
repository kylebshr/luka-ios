//
//  Bundle+Extensions.swift
//  Luka
//
//  Created by Kyle Bashour on 5/2/24.
//

import Foundation

extension Bundle {
    var version: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }

    var build: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    var buildNumber: Int {
        Int(build) ?? 0
    }

    var fullVersion: String {
        "\(version) (\(build))"
    }
}
