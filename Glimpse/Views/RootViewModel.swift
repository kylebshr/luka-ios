//
//  RootViewModel.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI
import KeychainAccess
import Dexcom
import Defaults

@Observable class RootViewModel {
    private let keychain = Keychain.shared

    var username: String? = Keychain.shared.username {
        didSet { keychain.username = username }
    }

    var password: String? = Keychain.shared.password {
        didSet { keychain.password = password }
    }

    var accountLocation: AccountLocation? = Defaults[.accountLocation] {
        didSet { Defaults[.accountLocation] = accountLocation }
    }

    var accountID: UUID? = Keychain.shared.accountID {
        didSet { keychain.accountID = accountID }
    }

    var sessionID: UUID? = Keychain.shared.sessionID {
        didSet { keychain.sessionID = sessionID }
    }

    var isSignedIn: Bool {
        username != nil && password != nil && accountLocation != nil
    }

    func signIn(
        username: String,
        password: String,
        accountLocation: AccountLocation
    ) async throws {
        let client = DexcomClient(
            username: username,
            password: password,
            existingAccountID: accountID, 
            existingSessionID: sessionID,
            accountLocation: accountLocation
        )

        (accountID, sessionID) = try await client.createSession()

        self.username = username
        self.password = password
        self.accountLocation = accountLocation
    }

    func signOut() {
        username = nil
        password = nil
        accountID = nil
        sessionID = nil
    }
}
