//
//  Defaults.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/24/24.
//

import Foundation

extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.com.kylebashour.Glimpse")!

    var username: String? {
        get { self[.usernameKey] }
        set { self[.usernameKey] = newValue }
    }

    var password: String? {
        get { self[.passwordKey] }
        set { self[.passwordKey] = newValue }
    }

    var accountID: UUID? {
        get { self[.accountIDKey].flatMap { UUID(uuidString: $0) } }
        set { self[.accountIDKey] = newValue?.uuidString }
    }

    var sessionID: UUID? {
        get { self[.sessionIDKey].flatMap { UUID(uuidString: $0) } }
        set { self[.sessionIDKey] = newValue?.uuidString }
    }
}

extension UserDefaults {
    subscript(key: String) -> String? {
        get { string(forKey: key) }
        set { set(newValue, forKey: key) }
    }
}
