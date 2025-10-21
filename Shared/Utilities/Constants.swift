//
//  Constants.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/12/24.
//

import Foundation

extension String {
    static let usernameKey = "username"
    static let passwordKey = "password"

    static let accountIDKey = "accountID"
    static let sessionIDKey = "sessionID"

    static let accountLocation = "accountLocation"
    static let targetRangeLowerBound = "targetRangeLowerBound"
    static let targetRangeUpperBound = "targetRangeUpperBound"
    static let graphUpperBound = "graphUpperBound"
    static let cachedReadings = "chachedReadings"
    static let sessionHistory = "sessionHistory"
}

extension CGFloat {
    static let spacing1: CGFloat = 2
    static let spacing3: CGFloat = 6
    static let spacing4: CGFloat = 8
    static let spacing6: CGFloat = 12
    static let spacing8: CGFloat = 16
    static let spacing10: CGFloat = 20
    static let spacing12: CGFloat = 24

    static let standardPadding = Self.spacing10

    static let horizontalSpacing = Self.spacing6

    static let largeVerticalSpacing: CGFloat = Self.spacing12
    static let verticalSpacing: CGFloat = Self.spacing8
    static let compactVerticalSpacing = Self.spacing6

    static let smallCornerRadius: CGFloat = 10
    static let defaultCornerRadius: CGFloat = 20
    static let sheetCornerRadius: CGFloat = .defaultCornerRadius + 10
}
