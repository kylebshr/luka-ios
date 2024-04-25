//
//  Keychain.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/12/24.
//

import Security
import KeychainAccess
import Foundation

extension Keychain {
    static var shared: Keychain {
        Keychain(
            service: "group.com.kylebashour.Glimpse",
            accessGroup: "group.com.kylebashour.Glimpse"
        ).synchronizable(true)
    }

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
