//
//  DexcomHelper.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/25.
//

import Defaults
import Dexcom
import Foundation

enum DexcomHelper {
    static let mockEmail = "demo@pitou.tech"

    /// Builds the client for a stored account: its credentials, its own readings
    /// cache, and a delegate that persists its refreshed session. Returns nil if
    /// the account's credentials can't be read.
    static func createService(
        for account: DexcomAccount,
        store: AccountStore = .shared
    ) async -> DexcomClientService? {
        guard let credentials = store.credentials(for: account.id) else {
            return nil
        }

        if credentials.isMock {
            return MockDexcomClient()
        }

        let client = DexcomClient(
            username: credentials.username,
            password: credentials.password,
            existingAccountID: credentials.dexcomAccountID,
            existingSessionID: credentials.sessionID,
            accountLocation: account.accountLocation
        )
        let delegate = KeychainDexcomDelegate(accountID: account.id, store: store)
        await client.setDelegate(delegate)

        let caching = CachingDexcomClient(
            wrapping: client,
            accountID: account.id,
            sessionDelegate: delegate
        )

        if Defaults[.useReadingsProxy] {
            return ProxyDexcomClient(
                wrapping: caching,
                username: credentials.username,
                password: credentials.password
            )
        }

        return caching
    }

    /// An uncached client for credentials that aren't stored yet, used to
    /// validate them with `createSession()` while signing in.
    static func createSignInService(
        username: String,
        password: String,
        accountLocation: AccountLocation
    ) -> DexcomClientService {
        if username == mockEmail {
            return MockDexcomClient()
        }

        return DexcomClient(
            username: username,
            password: password,
            accountLocation: accountLocation
        )
    }
}
