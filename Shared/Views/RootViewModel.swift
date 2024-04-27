//
//  RootViewModel.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI
import KeychainAccess
import Dexcom

@Observable class RootViewModel {
    private let keychain = Keychain.shared

    var username: String? {
        get {
            access(keyPath: \.username)
            return keychain.username
        }
        set {
            withMutation(keyPath: \.username) {
                keychain.username = newValue
            }
        }
    }

    var password: String? {
        get {
            access(keyPath: \.password)
            return keychain.password
        }
        set {
            withMutation(keyPath: \.password) {
                keychain.password = newValue
            }
        }
    }

    var accountID: UUID? {
        get {
            access(keyPath: \.accountID)
            return keychain.accountID
        }
        set {
            withMutation(keyPath: \.accountID) {
                keychain.accountID = newValue
            }
        }
    }

    var sessionID: UUID? {
        get {
            access(keyPath: \.sessionID)
            return keychain.sessionID
        }
        set {
            withMutation(keyPath: \.sessionID) {
                keychain.sessionID = newValue
            }
        }
    }

    func signIn(
        username: String,
        password: String,
        outsideUS: Bool
    ) async throws {
        let client = DexcomClient(
            username: username,
            password: password,
            outsideUS: outsideUS
        )

        (accountID, sessionID) = try await client.createSession()

        self.username = username
        self.password = password

        UserDefaults.shared.outsideUS = outsideUS
    }
}
