//
//  Keychain.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/12/24.
//

import Security
import KeychainAccess
import Foundation
import Dexcom
import Libre

extension Keychain {
    static var shared: Keychain {
        Keychain(
            service: "group.com.kylebashour.Glimpse",
            accessGroup: "group.com.kylebashour.Glimpse"
        )
        .synchronizable(true)
        .accessibility(.afterFirstUnlock)
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

    /// The Dexcom session, stored as its two IDs so credentials saved by
    /// pre-`DexcomSession` versions of the app keep working.
    var dexcomSession: DexcomSession? {
        get {
            guard let accountID, let sessionID else { return nil }
            return DexcomSession(accountID: accountID, sessionID: sessionID)
        }
        set {
            accountID = newValue?.accountID
            sessionID = newValue?.sessionID
        }
    }

    var libreSession: LibreSession? {
        get {
            self[.libreSessionKey]
                .flatMap { try? JSONDecoder().decode(LibreSession.self, from: Data($0.utf8)) }
        }
        set {
            self[.libreSessionKey] = newValue
                .flatMap { try? JSONEncoder().encode($0) }
                .flatMap { String(data: $0, encoding: .utf8) }
        }
    }
}
